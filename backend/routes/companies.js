// backend/routes/companies.js
const express = require('express');
const router = express.Router();
const { pool } = require('../middleware/auth');
const { authenticateUser, authorizeCompanyAccess, requireRole, requirePermission } = require('../middleware/auth');

// Apply authentication to all company routes
router.use(authenticateUser);

// =================================================================
// USER'S COMPANIES ROUTES
// =================================================================

/**
 * GET /api/user/companies
 * Get all companies the authenticated user has access to
 */
router.get('/user/companies', async (req, res) => {
  try {
    if (req.user.isDemo) {
      // Demo users only see demo company
      const demoCompany = await getDemoCompany();
      return res.json([{
        id: demoCompany.id,
        name: demoCompany.name,
        slug: demoCompany.slug,
        role: 'demo',
        permissions: { demo_access: true },
        is_demo: true
      }]);
    }

    const query = `
      SELECT 
        c.id,
        c.name,
        c.slug,
        c.email,
        c.subscription_plan,
        c.is_demo,
        c.status as company_status,
        uca.role,
        uca.permissions,
        uca.granted_at,
        uca.status as access_status
      FROM companies c
      JOIN user_company_access uca ON c.id = uca.company_id
      WHERE uca.user_id = $1 
        AND uca.status = 'active' 
        AND c.status = 'active'
      ORDER BY c.name
    `;

    const result = await pool.query(query, [req.user.id]);
    
    res.json(result.rows);
    
  } catch (error) {
    console.error('Error fetching user companies:', error);
    res.status(500).json({ 
      error: 'Failed to fetch companies',
      message: 'Unable to retrieve your companies' 
    });
  }
});

// =================================================================
// COMPANY MANAGEMENT ROUTES
// =================================================================

/**
 * POST /api/companies
 * Create a new company (user becomes owner)
 */
router.post('/companies', async (req, res) => {
  const client = await pool.connect();
  
  try {
    if (req.user.isDemo) {
      return res.status(403).json({
        error: 'Demo restriction',
        message: 'Demo users cannot create companies. Please sign up for a real account.'
      });
    }

    const { name, email, phone, address, subscription_plan = 'free' } = req.body;

    if (!name || !email) {
      return res.status(400).json({
        error: 'Missing required fields',
        message: 'Company name and email are required'
      });
    }

    // Generate slug from company name
    const slug = generateSlug(name);

    await client.query('BEGIN');

    // Create company
    const companyQuery = `
      INSERT INTO companies (name, slug, email, phone, address, subscription_plan, created_at, status)
      VALUES ($1, $2, $3, $4, $5, $6, NOW(), 'active')
      RETURNING *
    `;

    const companyResult = await client.query(companyQuery, [
      name, slug, email, phone, address, subscription_plan
    ]);

    const company = companyResult.rows[0];

    // Grant owner access to the creator
    const accessQuery = `
      INSERT INTO user_company_access (user_id, company_id, role, permissions, granted_at, status)
      VALUES ($1, $2, 'owner', '{"full_access": true}', NOW(), 'active')
      RETURNING *
    `;

    await client.query(accessQuery, [req.user.id, company.id]);

    await client.query('COMMIT');

    res.status(201).json({
      message: 'Company created successfully',
      company: company
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error creating company:', error);

    if (error.code === '23505') { // Unique constraint violation
      return res.status(409).json({
        error: 'Company already exists',
        message: 'A company with this name or email already exists'
      });
    }

    res.status(500).json({
      error: 'Failed to create company',
      message: 'Unable to create company'
    });
  } finally {
    client.release();
  }
});

/**
 * GET /api/companies/:companyId
 * Get company details (requires access)
 */
router.get('/companies/:companyId', authorizeCompanyAccess, async (req, res) => {
  try {
    res.json({
      company: req.company,
      userAccess: {
        role: req.userAccess.role,
        permissions: req.userAccess.permissions
      }
    });
  } catch (error) {
    console.error('Error fetching company:', error);
    res.status(500).json({
      error: 'Failed to fetch company',
      message: 'Unable to retrieve company details'
    });
  }
});

/**
 * PUT /api/companies/:companyId
 * Update company details (requires admin role)
 */
router.put('/companies/:companyId', authorizeCompanyAccess, requireRole('admin'), async (req, res) => {
  try {
    const { name, email, phone, address, subscription_plan } = req.body;
    const companyId = req.params.companyId;

    const query = `
      UPDATE companies 
      SET name = COALESCE($1, name),
          email = COALESCE($2, email),
          phone = COALESCE($3, phone),
          address = COALESCE($4, address),
          subscription_plan = COALESCE($5, subscription_plan)
      WHERE id = $6
      RETURNING *
    `;

    const result = await pool.query(query, [
      name, email, phone, address, subscription_plan, companyId
    ]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'Company not found',
        message: 'Unable to find company to update'
      });
    }

    res.json({
      message: 'Company updated successfully',
      company: result.rows[0]
    });

  } catch (error) {
    console.error('Error updating company:', error);
    res.status(500).json({
      error: 'Failed to update company',
      message: 'Unable to update company details'
    });
  }
});

// =================================================================
// USER INVITATION AND ACCESS MANAGEMENT
// =================================================================

/**
 * POST /api/companies/:companyId/invite
 * Invite a user to the company (requires admin role)
 */
router.post('/companies/:companyId/invite', authorizeCompanyAccess, requireRole('admin'), async (req, res) => {
  const client = await pool.connect();
  
  try {
    const { email, role = 'viewer', permissions = {} } = req.body;
    const companyId = req.params.companyId;

    if (!email) {
      return res.status(400).json({
        error: 'Email required',
        message: 'User email is required for invitation'
      });
    }

    if (!['viewer', 'accountant', 'admin'].includes(role)) {
      return res.status(400).json({
        error: 'Invalid role',
        message: 'Role must be viewer, accountant, or admin'
      });
    }

    await client.query('BEGIN');

    // Find user by email
    const userQuery = 'SELECT * FROM users WHERE email = $1 AND status = $2';
    const userResult = await client.query(userQuery, [email, 'active']);

    if (userResult.rows.length === 0) {
      // User doesn't exist - create pending invitation
      // For now, we'll return an error. In production, you might send an email invitation
      await client.query('ROLLBACK');
      return res.status(404).json({
        error: 'User not found',
        message: 'User must have an account before being invited'
      });
    }

    const user = userResult.rows[0];

    // Check if user already has access
    const existingAccessQuery = `
      SELECT * FROM user_company_access 
      WHERE user_id = $1 AND company_id = $2
    `;
    const existingAccess = await client.query(existingAccessQuery, [user.id, companyId]);

    if (existingAccess.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({
        error: 'User already has access',
        message: 'User already has access to this company'
      });
    }

    // Grant access
    const accessQuery = `
      INSERT INTO user_company_access (user_id, company_id, role, permissions, granted_by, granted_at, status)
      VALUES ($1, $2, $3, $4, $5, NOW(), 'active')
      RETURNING *
    `;

    const accessResult = await client.query(accessQuery, [
      user.id, companyId, role, JSON.stringify(permissions), req.user.id
    ]);

    await client.query('COMMIT');

    res.status(201).json({
      message: 'User invited successfully',
      access: accessResult.rows[0],
      user: {
        id: user.id,
        name: user.name,
        email: user.email
      }
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error inviting user:', error);
    res.status(500).json({
      error: 'Failed to invite user',
      message: 'Unable to invite user to company'
    });
  } finally {
    client.release();
  }
});

/**
 * GET /api/companies/:companyId/users
 * Get all users with access to the company (requires admin role)
 */
router.get('/companies/:companyId/users', authorizeCompanyAccess, requireRole('admin'), async (req, res) => {
  try {
    const companyId = req.params.companyId;

    const query = `
      SELECT 
        u.id,
        u.name,
        u.email,
        u.photo_url,
        uca.role,
        uca.permissions,
        uca.granted_at,
        uca.status,
        granted_by_user.name as granted_by_name
      FROM user_company_access uca
      JOIN users u ON uca.user_id = u.id
      LEFT JOIN users granted_by_user ON uca.granted_by = granted_by_user.id
      WHERE uca.company_id = $1
      ORDER BY uca.granted_at DESC
    `;

    const result = await pool.query(query, [companyId]);

    res.json(result.rows);

  } catch (error) {
    console.error('Error fetching company users:', error);
    res.status(500).json({
      error: 'Failed to fetch users',
      message: 'Unable to retrieve company users'
    });
  }
});

/**
 * PUT /api/companies/:companyId/users/:userId
 * Update user's role/permissions (requires admin role)
 */
router.put('/companies/:companyId/users/:userId', authorizeCompanyAccess, requireRole('admin'), async (req, res) => {
  try {
    const { companyId, userId } = req.params;
    const { role, permissions, status } = req.body;

    // Prevent self-modification of owner role
    if (userId == req.user.id && req.userAccess.role === 'owner') {
      return res.status(403).json({
        error: 'Cannot modify own owner access',
        message: 'Company owners cannot modify their own access'
      });
    }

    const query = `
      UPDATE user_company_access 
      SET role = COALESCE($1, role),
          permissions = COALESCE($2, permissions),
          status = COALESCE($3, status)
      WHERE company_id = $4 AND user_id = $5
      RETURNING *
    `;

    const result = await pool.query(query, [
      role, 
      permissions ? JSON.stringify(permissions) : null,
      status, 
      companyId, 
      userId
    ]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'User access not found',
        message: 'User does not have access to this company'
      });
    }

    res.json({
      message: 'User access updated successfully',
      access: result.rows[0]
    });

  } catch (error) {
    console.error('Error updating user access:', error);
    res.status(500).json({
      error: 'Failed to update user access',
      message: 'Unable to update user permissions'
    });
  }
});

/**
 * DELETE /api/companies/:companyId/users/:userId
 * Remove user's access to company (requires admin role)
 */
router.delete('/companies/:companyId/users/:userId', authorizeCompanyAccess, requireRole('admin'), async (req, res) => {
  try {
    const { companyId, userId } = req.params;

    // Prevent self-removal of owner
    if (userId == req.user.id && req.userAccess.role === 'owner') {
      return res.status(403).json({
        error: 'Cannot remove own owner access',
        message: 'Company owners cannot remove their own access'
      });
    }

    const query = `
      DELETE FROM user_company_access 
      WHERE company_id = $1 AND user_id = $2
      RETURNING *
    `;

    const result = await pool.query(query, [companyId, userId]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'User access not found',
        message: 'User does not have access to this company'
      });
    }

    res.json({
      message: 'User access removed successfully'
    });

  } catch (error) {
    console.error('Error removing user access:', error);
    res.status(500).json({
      error: 'Failed to remove user access',
      message: 'Unable to remove user access'
    });
  }
});

// =================================================================
// HELPER FUNCTIONS
// =================================================================

async function getDemoCompany() {
  const query = 'SELECT * FROM companies WHERE is_demo = true AND status = $1 LIMIT 1';
  const result = await pool.query(query, ['active']);
  return result.rows[0] || null;
}

function generateSlug(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .substring(0, 50);
}

module.exports = router;