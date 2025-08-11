from pydantic import BaseModel
from typing import List, Optional
from decimal import Decimal
from datetime import date

# ================== VAT MODELS ==================

class VATRate(BaseModel):
    id: Optional[int] = None
    country: str = "Ireland"
    rate_name: str  # 'Standard', 'Reduced', 'Zero', 'Exempt'
    rate_percentage: Decimal
    description: Optional[str] = None
    is_active: bool = True
    effective_from: date
    effective_until: Optional[date] = None
    created_at: Optional[str] = None

class ExpenseCategory(BaseModel):
    id: Optional[int] = None
    category_name: str
    category_type: str  # 'general', 'eworker', 'mileage', 'subsistence'
    default_vat_rate_id: Optional[int] = None
    supports_business_usage: bool = False
    default_business_usage: Decimal = Decimal('100.00')
    requires_receipt: bool = True
    description: Optional[str] = None
    is_active: bool = True
    created_at: Optional[str] = None

class BusinessUsageOption(BaseModel):
    id: Optional[str] = None
    percentage: Decimal
    label: str
    description: Optional[str] = None
    is_default: bool = False

# Enhanced Expense Model
class EnhancedExpense(BaseModel):
    id: Optional[str] = None
    company_id: str
    expense_date: date
    category: Optional[str] = None  # Legacy field
    category_id: Optional[int] = None  # New category reference
    description: str
    net_amount: Decimal
    vat_rate: Optional[Decimal] = Decimal('23.00')  # Legacy field
    vat_rate_id: Optional[int] = None  # New VAT rate reference
    vat_amount: Optional[Decimal] = None
    gross_amount: Optional[Decimal] = None
    supplier_name: Optional[str] = None
    paid: bool = False
    
    # Enhanced fields
    business_usage_percentage: Decimal = Decimal('100.00')
    deductible_amount: Optional[Decimal] = None
    expense_type: str = 'general'  # 'general', 'eworker', 'mileage', 'subsistence'
    
    # E-worker specific fields
    eworker_days: Optional[Decimal] = None
    eworker_rate: Optional[Decimal] = None
    
    # Mileage specific fields
    mileage_km: Optional[Decimal] = None
    mileage_rate: Optional[Decimal] = Decimal('0.3708')  # Irish Revenue 2024 rate
    
    receipt_required: bool = True
    notes: Optional[str] = None
    status: str = "pending"
    created_at: Optional[str] = None

# Enhanced Invoice Model
class EnhancedInvoice(BaseModel):
    id: Optional[str] = None
    company_id: str
    invoice_number: str
    issue_date: date
    due_date: Optional[date] = None
    customer_name: str
    net_amount: Decimal
    vat_rate: Optional[Decimal] = Decimal('23.00')  # Legacy field
    vat_rate_id: Optional[int] = None  # New VAT rate reference
    vat_amount: Optional[Decimal] = None
    gross_amount: Optional[Decimal] = None
    paid: bool = False
    
    # Enhanced fields
    invoice_type: str = 'standard'  # 'standard', 'reverse_charge', 'export', 'exempt'
    customer_vat_number: Optional[str] = None
    customer_country: str = 'Ireland'
    description: Optional[str] = None
    status: str = "pending"
    created_at: Optional[str] = None

class EWorkerPeriod(BaseModel):
    id: Optional[str] = None
    company_id: str
    period_start: date
    period_end: date
    total_days: Decimal
    daily_rate: Decimal
    total_amount: Decimal
    status: str = 'draft'  # 'draft', 'logged', 'paid'
    created_at: Optional[str] = None

class MileageLog(BaseModel):
    id: Optional[str] = None
    company_id: str
    expense_id: Optional[str] = None
    trip_date: date
    from_location: str
    to_location: str
    purpose: str
    km_distance: Decimal
    rate_per_km: Decimal
    total_amount: Decimal
    created_at: Optional[str] = None

# Request models for API
class ExpenseRequest(BaseModel):
    company_id: str
    expense_date: str  # Will be converted to date
    category_id: Optional[str] = None
    description: str
    net_amount: float
    vat_rate_id: Optional[str] = None
    supplier_name: Optional[str] = None
    business_usage_percentage: Optional[float] = 100.0
    expense_type: str = 'general'
    eworker_days: Optional[float] = None
    eworker_rate: Optional[float] = None
    mileage_km: Optional[float] = None
    notes: Optional[str] = None

class InvoiceRequest(BaseModel):
    company_id: str
    invoice_number: str
    issue_date: str  # Will be converted to date
    due_date: Optional[str] = None
    customer_name: str
    net_amount: float
    vat_rate_id: Optional[str] = None
    invoice_type: str = 'standard'
    customer_vat_number: Optional[str] = None
    customer_country: str = 'Ireland'
    description: Optional[str] = None

class EWorkerRequest(BaseModel):
    company_id: str
    period_start: str
    period_end: str
    total_days: float
    daily_rate: float

class MileageRequest(BaseModel):
    company_id: str
    expense_id: Optional[str] = None
    trip_date: str
    from_location: str
    to_location: str
    purpose: str
    km_distance: float
    rate_per_km: Optional[float] = 0.3708

# Response models
class VATCalculationResponse(BaseModel):
    net_amount: Decimal
    vat_rate_percentage: Decimal
    vat_amount: Decimal
    gross_amount: Decimal
    deductible_amount: Optional[Decimal] = None
    business_usage_percentage: Optional[Decimal] = None

class ExpenseCategoryResponse(BaseModel):
    categories: List[ExpenseCategory]
    vat_rates: List[VATRate]
    business_usage_options: List[BusinessUsageOption]