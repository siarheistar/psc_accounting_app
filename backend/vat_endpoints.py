from fastapi import APIRouter, HTTPException, Query
from typing import List, Dict, Optional
from decimal import Decimal
from datetime import date, datetime
import uuid
import logging

from vat_models import (
    VATRate, ExpenseCategory, BusinessUsageOption, EnhancedExpense, EnhancedInvoice,
    EWorkerPeriod, MileageLog, ExpenseRequest, InvoiceRequest, EWorkerRequest, 
    MileageRequest, VATCalculationResponse, ExpenseCategoryResponse
)
from vat_service import VATService
from database import execute_query

logger = logging.getLogger(__name__)
router = APIRouter()

# ================== VAT CONFIGURATION ENDPOINTS ==================

@router.get("/vat/rates", response_model=List[VATRate])
async def get_vat_rates(country: str = "Ireland", active_only: bool = True):
    """Get VAT rates for a country"""
    return VATService.get_vat_rates(country, active_only)

@router.get("/vat/expense-categories", response_model=ExpenseCategoryResponse)
async def get_expense_categories():
    """Get all expense categories with VAT rates and business usage options"""
    categories = VATService.get_expense_categories()
    vat_rates = VATService.get_vat_rates()
    business_usage_options = VATService.get_business_usage_options()
    
    return ExpenseCategoryResponse(
        categories=categories,
        vat_rates=vat_rates,
        business_usage_options=business_usage_options
    )

@router.post("/vat/calculate")
async def calculate_vat(
    net_amount: float,
    vat_rate_id: Optional[str] = None,
    vat_rate_percentage: Optional[float] = None,
    business_usage_percentage: float = 100.0
) -> VATCalculationResponse:
    """Calculate VAT amounts"""
    return VATService.calculate_vat(
        net_amount=Decimal(str(net_amount)),
        vat_rate_id=vat_rate_id,
        vat_rate_percentage=Decimal(str(vat_rate_percentage)) if vat_rate_percentage else None,
        business_usage_percentage=Decimal(str(business_usage_percentage))
    )

# ================== ENHANCED EXPENSE ENDPOINTS ==================

@router.post("/expenses/enhanced")
async def create_enhanced_expense(expense: ExpenseRequest):
    """Create an enhanced expense with VAT and business usage calculations"""
    
    try:
        # Convert date string to date object
        expense_date = datetime.strptime(expense.expense_date, "%Y-%m-%d").date()
        
        # Calculate amounts based on expense type
        net_amount = Decimal(str(expense.net_amount))
        
        if expense.expense_type == 'eworker' and expense.eworker_days and expense.eworker_rate:
            # Override net_amount for e-worker expenses
            net_amount = VATService.calculate_eworker_expense(
                Decimal(str(expense.eworker_days)), 
                Decimal(str(expense.eworker_rate))
            )
        elif expense.expense_type == 'mileage' and expense.mileage_km:
            # Override net_amount for mileage expenses
            mileage_rate = VATService.get_irish_mileage_rate()
            net_amount = VATService.calculate_mileage_expense(
                Decimal(str(expense.mileage_km)), 
                mileage_rate
            )
        
        # Calculate VAT
        vat_calc = VATService.calculate_vat(
            net_amount=net_amount,
            vat_rate_id=expense.vat_rate_id,
            business_usage_percentage=Decimal(str(expense.business_usage_percentage or 100.0))
        )
        
        # Insert expense
        query = """
        INSERT INTO prod.expenses 
        (id, company_id, expense_date, category_id, description, net_amount, 
         vat_rate_id, vat_amount, gross_amount, supplier_name, business_usage_percentage,
         deductible_amount, expense_type, eworker_days, eworker_rate, mileage_km, 
         mileage_rate, notes, receipt_required, paid)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
        """
        
        expense_id = str(uuid.uuid4())
        
        params = [
            expense_id,
            expense.company_id,
            expense_date,
            expense.category_id,
            expense.description,
            net_amount,
            expense.vat_rate_id,
            vat_calc.vat_amount,
            vat_calc.gross_amount,
            expense.supplier_name,
            vat_calc.business_usage_percentage,
            vat_calc.deductible_amount,
            expense.expense_type,
            Decimal(str(expense.eworker_days)) if expense.eworker_days else None,
            Decimal(str(expense.eworker_rate)) if expense.eworker_rate else None,
            Decimal(str(expense.mileage_km)) if expense.mileage_km else None,
            VATService.get_irish_mileage_rate() if expense.expense_type == 'mileage' else None,
            expense.notes,
            True,  # receipt_required default
            False  # paid default
        ]
        
        result = execute_query(query, params)
        
        if result:
            return {
                "id": expense_id,
                "message": "Enhanced expense created successfully",
                "vat_calculation": vat_calc.dict(),
                "calculated_net_amount": float(net_amount)
            }
        else:
            raise HTTPException(status_code=400, detail="Failed to create expense")
            
    except Exception as e:
        logger.error(f"Error creating enhanced expense: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/expenses/enhanced/{company_id}")
async def get_enhanced_expenses(company_id: str):
    """Get enhanced expenses with VAT calculations"""
    
    query = """
    SELECT e.id, e.company_id, e.expense_date, e.description, e.net_amount,
           e.vat_amount, e.gross_amount, e.supplier_name, e.business_usage_percentage,
           e.deductible_amount, e.expense_type, e.eworker_days, e.eworker_rate,
           e.mileage_km, e.mileage_rate, e.notes, e.receipt_required, e.paid,
           e.created_at, ec.category_name, vr.rate_name, vr.rate_percentage
    FROM prod.expenses e
    LEFT JOIN prod.expense_categories ec ON e.category_id = ec.id
    LEFT JOIN prod.vat_rates vr ON e.vat_rate_id = vr.id
    WHERE e.company_id = %s
    ORDER BY e.expense_date DESC, e.created_at DESC
    """
    
    try:
        result = execute_query(query, [company_id])
        expenses = []
        
        for row in result:
            expenses.append({
                "id": str(row[0]),
                "company_id": row[1],
                "expense_date": row[2].isoformat() if row[2] else None,
                "description": row[3],
                "net_amount": float(row[4]) if row[4] else 0,
                "vat_amount": float(row[5]) if row[5] else 0,
                "gross_amount": float(row[6]) if row[6] else 0,
                "supplier_name": row[7],
                "business_usage_percentage": float(row[8]) if row[8] else 100,
                "deductible_amount": float(row[9]) if row[9] else 0,
                "expense_type": row[10] or 'general',
                "eworker_days": float(row[11]) if row[11] else None,
                "eworker_rate": float(row[12]) if row[12] else None,
                "mileage_km": float(row[13]) if row[13] else None,
                "mileage_rate": float(row[14]) if row[14] else None,
                "notes": row[15],
                "receipt_required": row[16],
                "paid": row[17],
                "created_at": row[18].isoformat() if row[18] else None,
                "category_name": row[19],
                "vat_rate_name": row[20],
                "vat_rate_percentage": float(row[21]) if row[21] else 0
            })
        
        return expenses
        
    except Exception as e:
        logger.error(f"Error getting enhanced expenses: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

# ================== ENHANCED INVOICE ENDPOINTS ==================

@router.post("/invoices/enhanced")
async def create_enhanced_invoice(invoice: InvoiceRequest):
    """Create an enhanced invoice with VAT calculations"""
    
    try:
        # Convert date strings to date objects
        issue_date = datetime.strptime(invoice.issue_date, "%Y-%m-%d").date()
        due_date = datetime.strptime(invoice.due_date, "%Y-%m-%d").date() if invoice.due_date else None
        
        # Calculate VAT
        net_amount = Decimal(str(invoice.net_amount))
        vat_calc = VATService.calculate_vat(
            net_amount=net_amount,
            vat_rate_id=invoice.vat_rate_id
        )
        
        # Insert invoice
        query = """
        INSERT INTO prod.invoices 
        (id, company_id, invoice_number, issue_date, due_date, customer_name, 
         net_amount, vat_rate_id, vat_amount, gross_amount, invoice_type, 
         customer_vat_number, customer_country, paid)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
        """
        
        invoice_id = str(uuid.uuid4())
        
        params = [
            invoice_id,
            invoice.company_id,
            invoice.invoice_number,
            issue_date,
            due_date,
            invoice.customer_name,
            net_amount,
            invoice.vat_rate_id,
            vat_calc.vat_amount,
            vat_calc.gross_amount,
            invoice.invoice_type,
            invoice.customer_vat_number,
            invoice.customer_country,
            False  # paid default
        ]
        
        result = execute_query(query, params)
        
        if result:
            return {
                "id": invoice_id,
                "message": "Enhanced invoice created successfully",
                "vat_calculation": vat_calc.dict()
            }
        else:
            raise HTTPException(status_code=400, detail="Failed to create invoice")
            
    except Exception as e:
        logger.error(f"Error creating enhanced invoice: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/invoices/enhanced/{company_id}")
async def get_enhanced_invoices(company_id: str):
    """Get enhanced invoices with VAT calculations"""
    
    query = """
    SELECT i.id, i.company_id, i.invoice_number, i.issue_date, i.due_date,
           i.customer_name, i.net_amount, i.vat_amount, i.gross_amount,
           i.invoice_type, i.customer_vat_number, i.customer_country,
           i.paid, i.created_at, vr.rate_name, vr.rate_percentage
    FROM prod.invoices i
    LEFT JOIN prod.vat_rates vr ON i.vat_rate_id = vr.id
    WHERE i.company_id = %s
    ORDER BY i.issue_date DESC, i.created_at DESC
    """
    
    try:
        result = execute_query(query, [company_id])
        invoices = []
        
        for row in result:
            invoices.append({
                "id": str(row[0]),
                "company_id": row[1],
                "invoice_number": row[2],
                "issue_date": row[3].isoformat() if row[3] else None,
                "due_date": row[4].isoformat() if row[4] else None,
                "customer_name": row[5],
                "net_amount": float(row[6]) if row[6] else 0,
                "vat_amount": float(row[7]) if row[7] else 0,
                "gross_amount": float(row[8]) if row[8] else 0,
                "invoice_type": row[9] or 'standard',
                "customer_vat_number": row[10],
                "customer_country": row[11] or 'Ireland',
                "paid": row[12],
                "created_at": row[13].isoformat() if row[13] else None,
                "vat_rate_name": row[14],
                "vat_rate_percentage": float(row[15]) if row[15] else 0
            })
        
        return invoices
        
    except Exception as e:
        logger.error(f"Error getting enhanced invoices: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

# ================== E-WORKER ENDPOINTS ==================

@router.post("/eworker/period")
async def create_eworker_period(eworker: EWorkerRequest):
    """Create an e-worker period entry"""
    
    try:
        # Convert date strings
        period_start = datetime.strptime(eworker.period_start, "%Y-%m-%d").date()
        period_end = datetime.strptime(eworker.period_end, "%Y-%m-%d").date()
        
        # Calculate total amount
        total_days = Decimal(str(eworker.total_days))
        daily_rate = Decimal(str(eworker.daily_rate))
        total_amount = VATService.calculate_eworker_expense(total_days, daily_rate)
        
        # Insert e-worker period
        query = """
        INSERT INTO prod.eworker_periods 
        (id, company_id, period_start, period_end, total_days, daily_rate, total_amount, status)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
        """
        
        eworker_id = str(uuid.uuid4())
        
        params = [
            eworker_id,
            eworker.company_id,
            period_start,
            period_end,
            total_days,
            daily_rate,
            total_amount,
            'draft'
        ]
        
        result = execute_query(query, params)
        
        if result:
            return {
                "id": eworker_id,
                "message": "E-worker period created successfully",
                "total_amount": float(total_amount)
            }
        else:
            raise HTTPException(status_code=400, detail="Failed to create e-worker period")
            
    except Exception as e:
        logger.error(f"Error creating e-worker period: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/eworker/periods/{company_id}")
async def get_eworker_periods(company_id: str):
    """Get e-worker periods for a company"""
    
    query = """
    SELECT id, company_id, period_start, period_end, total_days, 
           daily_rate, total_amount, status, created_at
    FROM prod.eworker_periods
    WHERE company_id = %s
    ORDER BY period_start DESC
    """
    
    try:
        result = execute_query(query, [company_id])
        periods = []
        
        for row in result:
            periods.append({
                "id": str(row[0]),
                "company_id": row[1],
                "period_start": row[2].isoformat() if row[2] else None,
                "period_end": row[3].isoformat() if row[3] else None,
                "total_days": float(row[4]) if row[4] else 0,
                "daily_rate": float(row[5]) if row[5] else 0,
                "total_amount": float(row[6]) if row[6] else 0,
                "status": row[7],
                "created_at": row[8].isoformat() if row[8] else None
            })
        
        return periods
        
    except Exception as e:
        logger.error(f"Error getting e-worker periods: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

# ================== MILEAGE ENDPOINTS ==================

@router.post("/mileage/log")
async def create_mileage_log(mileage: MileageRequest):
    """Create a mileage log entry"""
    
    try:
        # Convert date string
        trip_date = datetime.strptime(mileage.trip_date, "%Y-%m-%d").date()
        
        # Calculate total amount
        km_distance = Decimal(str(mileage.km_distance))
        rate_per_km = Decimal(str(mileage.rate_per_km or 0.3708))
        total_amount = VATService.calculate_mileage_expense(km_distance, rate_per_km)
        
        # Insert mileage log
        query = """
        INSERT INTO prod.mileage_log 
        (id, company_id, expense_id, trip_date, from_location, to_location, 
         purpose, km_distance, rate_per_km, total_amount)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
        """
        
        mileage_id = str(uuid.uuid4())
        
        params = [
            mileage_id,
            mileage.company_id,
            mileage.expense_id,
            trip_date,
            mileage.from_location,
            mileage.to_location,
            mileage.purpose,
            km_distance,
            rate_per_km,
            total_amount
        ]
        
        result = execute_query(query, params)
        
        if result:
            return {
                "id": mileage_id,
                "message": "Mileage log created successfully",
                "total_amount": float(total_amount)
            }
        else:
            raise HTTPException(status_code=400, detail="Failed to create mileage log")
            
    except Exception as e:
        logger.error(f"Error creating mileage log: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/mileage/logs/{company_id}")
async def get_mileage_logs(company_id: str):
    """Get mileage logs for a company"""
    
    query = """
    SELECT id, company_id, expense_id, trip_date, from_location, to_location,
           purpose, km_distance, rate_per_km, total_amount, created_at
    FROM prod.mileage_log
    WHERE company_id = %s
    ORDER BY trip_date DESC
    """
    
    try:
        result = execute_query(query, [company_id])
        logs = []
        
        for row in result:
            logs.append({
                "id": str(row[0]),
                "company_id": row[1],
                "expense_id": str(row[2]) if row[2] else None,
                "trip_date": row[3].isoformat() if row[3] else None,
                "from_location": row[4],
                "to_location": row[5],
                "purpose": row[6],
                "km_distance": float(row[7]) if row[7] else 0,
                "rate_per_km": float(row[8]) if row[8] else 0,
                "total_amount": float(row[9]) if row[9] else 0,
                "created_at": row[10].isoformat() if row[10] else None
            })
        
        return logs
        
    except Exception as e:
        logger.error(f"Error getting mileage logs: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

# ================== VAT REPORTING ENDPOINTS ==================

@router.get("/vat/summary/{company_id}")
async def get_vat_summary(
    company_id: str,
    start_date: str = Query(..., description="Start date (YYYY-MM-DD)"),
    end_date: str = Query(..., description="End date (YYYY-MM-DD)")
):
    """Get VAT summary for a company in a period"""
    
    try:
        summary = VATService.get_vat_summary_for_period(company_id, start_date, end_date)
        
        # Convert Decimal to float for JSON serialization
        return {
            "company_id": company_id,
            "period_start": start_date,
            "period_end": end_date,
            "total_sales": float(summary['total_sales']),
            "total_output_vat": float(summary['total_output_vat']),
            "total_purchases": float(summary['total_purchases']),
            "total_input_vat": float(summary['total_input_vat']),
            "net_vat_due": float(summary['net_vat_due'])
        }
        
    except Exception as e:
        logger.error(f"Error getting VAT summary: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")