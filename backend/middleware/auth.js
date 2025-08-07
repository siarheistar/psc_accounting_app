// backend/middleware/auth.js
const admin = require('firebase-admin');
const { Pool } = require('pg');

// Initialize Firebase Admin (you'll need to add your service account key)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(), // or use serviceAccountKey
    // credential: admin.credential.cert(require('../config/firebase-service-account.json')),
  });
}

// Database connection
const pool = new Pool({
  host: 'pscdb.cnacsqi4u8qw.eu-west-1.rds.amazonaws.com',
  port: 5432,
  database: 'pscdb',
  user: 'postgres',
  password: process.env.DB_PASSWORD, // Store password in environment variable
  ssl: {
    rejectUnauthorized: false
  }
});

/**
 * Authentication middleware - verifies Firebase tokens and sets user context
 */
async function authenticateUser(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    
    // Check for demo routes - allow without authentication
    if (req.path.includes('/demo/') || req.path === '/health') {
      req.user = { 
        isDemo: true, 
        id: null,
        email: 'demo@example.com',
        name: 'Demo User'
      };
      return next();
    }

    // Require authentication for non-demo routes
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ 
        error: 'Authorization header required',
        message: 'Please provide a valid Bearer token' 
      });
    }

    const token = authHeader.split(' ')[1];
    
    // Verify Firebase token
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    // Get user from database
    const user = await getUserByFirebaseUid(decodedToken.uid);
    
    if (!user) {
      // User not in database yet - create them
      const newUser = await createUserFromFirebaseToken(decodedToken);
      req.user = newUser;
    } else {
      // Update last login
      await updateUserLastLogin(user.id);
      req.user = user;
    }

    next();
    
  } catch (error) {
    console.error('Authentication error:', error);
    
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ 
        error: 'Token expired',
        message: 'Please refresh your authentication token' 
      });
    }
    
    if (error.code === 'auth/id-token-revoked') {
      return res.status(401).json({ 
        error: 'Token revoked',
        message: 'Your session has been revoked. Please sign in again.' 
      });
    }
    
    return res.status(401).json({ 
      error: 'Invalid token',
      message: 'Authentication failed' 
    });
  }
}

/**
 * Company authorization middleware - ensures user has access to requested company
 */
async function authorizeCompanyAccess(req, res, next) {
  try {
    // Skip authorization for demo users
    if (req.user.isDemo) {
      const demoCompany = await getDemoCompany();
      req.company = demoCompany;
      req.userAccess = {
        role: 'demo',
        permissions: { demo_access: true },
        company_id: demoCompany.id
      };
      return next();
    }

    // Get company ID from URL params or request body
    const companyId = req.params.companyId || req.body.company_id || req.query.company_id;
    
    if (!companyId) {
      return res.status(400).json({ 
        error: 'Company ID required',
        message: 'Please specify which company you want to access' 
      });
    }

    // Check user's access to this company
    const access = await checkUserCompanyAccess(req.user.id, companyId);
    
    if (!access || access.status !== 'active') {
      return res.status(403).json({ 
        error: 'Access denied',
        message: 'You do not have permission to access this company' 
      });
    }

    // Get company details
    const company = await getCompanyById(companyId);
    
    if (!company || company.status !== 'active') {
      return res.status(404).json({ 
        error: 'Company not found',
        message: 'The requested company does not exist or is inactive' 
      });
    }

    // Set context for downstream middleware/routes
    req.company = company;
    req.userAccess = access;
    
    next();
    
  } catch (error) {
    console.error('Company authorization error:', error);
    return res.status(500).json({ 
      error: 'Authorization failed',
      message: 'Unable to verify company access' 
    });
  }
}

/**
 * Role-based permission middleware
 */
function requireRole(requiredRole) {
  return (req, res, next) => {
    if (req.user.isDemo) {
      return next(); // Demo users can do anything in demo mode
    }

    const userRole = req.userAccess?.role;
    const roleHierarchy = ['viewer', 'accountant', 'admin', 'owner'];
    
    const userRoleIndex = roleHierarchy.indexOf(userRole);
    const requiredRoleIndex = roleHierarchy.indexOf(requiredRole);
    
    if (userRoleIndex === -1 || userRoleIndex < requiredRoleIndex) {
      return res.status(403).json({
        error: 'Insufficient permissions',
        message: `This action requires ${requiredRole} role or higher`
      });
    }
    
    next();
  };
}

/**
 * Permission-based middleware
 */
function requirePermission(permission) {
  return (req, res, next) => {
    if (req.user.isDemo) {
      return next(); // Demo users can do anything in demo mode
    }

    const userPermissions = req.userAccess?.permissions || {};
    
    // Check if user has specific permission
    if (userPermissions[permission] === true) {
      return next();
    }

    // Check role-based permissions
    const role = req.userAccess?.role;
    const rolePermissions = getRolePermissions(role);
    
    if (rolePermissions[permission] === true) {
      return next();
    }

    return res.status(403).json({
      error: 'Permission denied',
      message: `You don't have permission to: ${permission}`
    });
  };
}

// =================================================================
// DATABASE HELPER FUNCTIONS
// =================================================================

async function getUserByFirebaseUid(firebaseUid) {
  const query = 'SELECT * FROM users WHERE firebase_uid = $1 AND status = $2';
  const result = await pool.query(query, [firebaseUid, 'active']);
  return result.rows[0] || null;
}

async function createUserFromFirebaseToken(decodedToken) {
  const query = `
    INSERT INTO users (firebase_uid, email, name, photo_url, created_at, last_login, status)
    VALUES ($1, $2, $3, $4, NOW(), NOW(), 'active')
    RETURNING *
  `;
  
  const values = [
    decodedToken.uid,
    decodedToken.email,
    decodedToken.name || null,
    decodedToken.picture || null
  ];
  
  const result = await pool.query(query, values);
  return result.rows[0];
}

async function updateUserLastLogin(userId) {
  const query = 'UPDATE users SET last_login = NOW() WHERE id = $1';
  await pool.query(query, [userId]);
}

async function checkUserCompanyAccess(userId, companyId) {
  const query = `
    SELECT uca.*, c.name as company_name, c.is_demo
    FROM user_company_access uca
    JOIN companies c ON uca.company_id = c.id
    WHERE uca.user_id = $1 AND uca.company_id = $2 AND uca.status = 'active'
  `;
  
  const result = await pool.query(query, [userId, companyId]);
  return result.rows[0] || null;
}

async function getCompanyById(companyId) {
  const query = 'SELECT * FROM companies WHERE id = $1';
  const result = await pool.query(query, [companyId]);
  return result.rows[0] || null;
}

async function getDemoCompany() {
  const query = 'SELECT * FROM companies WHERE is_demo = true AND status = $1 LIMIT 1';
  const result = await pool.query(query, ['active']);
  return result.rows[0] || null;
}

function getRolePermissions(role) {
  const permissions = {
    viewer: {
      read_invoices: true,
      read_expenses: true,
      read_payroll: true,
      read_reports: true
    },
    accountant: {
      read_invoices: true,
      create_invoices: true,
      edit_invoices: true,
      read_expenses: true,
      create_expenses: true,
      edit_expenses: true,
      read_payroll: true,
      create_payroll: true,
      edit_payroll: true,
      read_reports: true,
      export_data: true
    },
    admin: {
      read_invoices: true,
      create_invoices: true,
      edit_invoices: true,
      delete_invoices: true,
      read_expenses: true,
      create_expenses: true,
      edit_expenses: true,
      delete_expenses: true,
      read_payroll: true,
      create_payroll: true,
      edit_payroll: true,
      delete_payroll: true,
      read_reports: true,
      export_data: true,
      manage_users: true,
      edit_company: true
    },
    owner: {
      // Owners have all permissions
      read_invoices: true,
      create_invoices: true,
      edit_invoices: true,
      delete_invoices: true,
      read_expenses: true,
      create_expenses: true,
      edit_expenses: true,
      delete_expenses: true,
      read_payroll: true,
      create_payroll: true,
      edit_payroll: true,
      delete_payroll: true,
      read_reports: true,
      export_data: true,
      manage_users: true,
      edit_company: true,
      delete_company: true,
      manage_billing: true
    }
  };
  
  return permissions[role] || {};
}

// Export pool for use in other files
module.exports = {
  authenticateUser,
  authorizeCompanyAccess,
  requireRole,
  requirePermission,
  pool
};