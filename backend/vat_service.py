from decimal import Decimal, ROUND_HALF_UP
from typing import List, Dict, Optional, Tuple
from database import execute_query
from vat_models import VATRate, ExpenseCategory, BusinessUsageOption, VATCalculationResponse
import logging

logger = logging.getLogger(__name__)

class VATService:
    """Service class for VAT calculations and management"""
    
    @staticmethod
    def get_vat_rates(country: str = "Ireland", active_only: bool = True) -> List[VATRate]:
        """Get VAT rates for a specific country"""
        query = """
        SELECT id, country, rate_name, rate_percentage, description, 
               is_active, effective_from, effective_until, created_at
        FROM public.vat_rates
        WHERE country = %s
        """
        params = [country]
        
        if active_only:
            query += " AND is_active = true"
        
        query += " ORDER BY rate_percentage DESC"
        
        try:
            result = execute_query(query, params, fetch=True)
            vat_rates = []
            for row in result:
                vat_rates.append(VATRate(
                    id=row['id'],
                    country=row['country'],
                    rate_name=row['rate_name'],
                    rate_percentage=Decimal(str(row['rate_percentage'])),
                    description=row['description'],
                    is_active=row['is_active'],
                    effective_from=row['effective_from'],
                    effective_until=row['effective_until'],
                    created_at=str(row['created_at']) if row['created_at'] else None
                ))
            return vat_rates
        except Exception as e:
            logger.error(f"Error getting VAT rates: {e}")
            return []
    
    @staticmethod
    def get_expense_categories() -> List[ExpenseCategory]:
        """Get all expense categories"""
        query = """
        SELECT id, category_name, category_type, default_vat_rate_id,
               supports_business_usage, default_business_usage, requires_receipt,
               description, is_active, created_at
        FROM public.expense_categories
        WHERE is_active = true
        ORDER BY category_name
        """
        
        try:
            result = execute_query(query, fetch=True)
            categories = []
            for row in result:
                categories.append(ExpenseCategory(
                    id=row['id'],
                    category_name=row['category_name'],
                    category_type=row['category_type'],
                    default_vat_rate_id=row['default_vat_rate_id'] if row['default_vat_rate_id'] else None,
                    supports_business_usage=row['supports_business_usage'],
                    default_business_usage=Decimal(str(row['default_business_usage'])),
                    requires_receipt=row['requires_receipt'],
                    description=row['description'],
                    is_active=row['is_active'],
                    created_at=str(row['created_at']) if row['created_at'] else None
                ))
            return categories
        except Exception as e:
            logger.error(f"Error getting expense categories: {e}")
            return []
    
    @staticmethod
    def get_business_usage_options() -> List[BusinessUsageOption]:
        """Get business usage percentage options"""
        query = """
        SELECT id, percentage, label, description, is_default
        FROM public.business_usage_options
        ORDER BY percentage DESC
        """
        
        try:
            result = execute_query(query, fetch=True)
            options = []
            for row in result:
                options.append(BusinessUsageOption(
                    id=row['id'],
                    percentage=Decimal(str(row['percentage'])),
                    label=row['label'],
                    description=row['description'],
                    is_default=row['is_default']
                ))
            return options
        except Exception as e:
            logger.error(f"Error getting business usage options: {e}")
            return []
    
    @staticmethod
    def calculate_vat(
        net_amount: Decimal, 
        vat_rate_id: Optional[int] = None, 
        vat_rate_percentage: Optional[Decimal] = None,
        business_usage_percentage: Decimal = Decimal('100.00')
    ) -> VATCalculationResponse:
        """Calculate VAT amounts with business usage"""
        
        # Get VAT rate percentage if not provided
        if vat_rate_percentage is None and vat_rate_id:
            vat_rate_percentage = VATService.get_vat_rate_percentage(vat_rate_id)
        
        if vat_rate_percentage is None:
            vat_rate_percentage = Decimal('23.00')  # Default Irish standard rate
        
        # Calculate amounts
        vat_amount = (net_amount * vat_rate_percentage / Decimal('100')).quantize(
            Decimal('0.01'), rounding=ROUND_HALF_UP
        )
        gross_amount = net_amount + vat_amount
        
        # Calculate deductible amount based on business usage
        deductible_amount = (net_amount * business_usage_percentage / Decimal('100')).quantize(
            Decimal('0.01'), rounding=ROUND_HALF_UP
        )
        
        return VATCalculationResponse(
            net_amount=net_amount,
            vat_rate_percentage=vat_rate_percentage,
            vat_amount=vat_amount,
            gross_amount=gross_amount,
            deductible_amount=deductible_amount,
            business_usage_percentage=business_usage_percentage
        )
    
    @staticmethod
    def calculate_vat_from_gross(
        gross_amount: Decimal, 
        vat_rate_id: Optional[int] = None, 
        vat_rate_percentage: Optional[Decimal] = None,
        business_usage_percentage: Decimal = Decimal('100.00')
    ) -> VATCalculationResponse:
        """Calculate VAT breakdown from gross amount with business usage"""
        
        # Get VAT rate percentage if not provided
        if vat_rate_percentage is None and vat_rate_id:
            vat_rate_percentage = VATService.get_vat_rate_percentage(vat_rate_id)
        
        if vat_rate_percentage is None:
            vat_rate_percentage = Decimal('23.00')  # Default Irish standard rate
        
        # Calculate net amount from gross (reverse VAT calculation)
        # gross_amount = net_amount * (1 + vat_rate/100)
        # net_amount = gross_amount / (1 + vat_rate/100)
        vat_multiplier = Decimal('1') + (vat_rate_percentage / Decimal('100'))
        net_amount = (gross_amount / vat_multiplier).quantize(
            Decimal('0.01'), rounding=ROUND_HALF_UP
        )
        
        # Calculate VAT amount
        vat_amount = gross_amount - net_amount
        
        # Calculate deductible amount based on business usage
        deductible_amount = (net_amount * business_usage_percentage / Decimal('100')).quantize(
            Decimal('0.01'), rounding=ROUND_HALF_UP
        )
        
        return VATCalculationResponse(
            net_amount=net_amount,
            vat_rate_percentage=vat_rate_percentage,
            vat_amount=vat_amount,
            gross_amount=gross_amount,
            deductible_amount=deductible_amount,
            business_usage_percentage=business_usage_percentage
        )
    
    @staticmethod
    def get_vat_rate_percentage(vat_rate_id: int) -> Optional[Decimal]:
        """Get VAT rate percentage by ID"""
        query = """
        SELECT rate_percentage 
        FROM public.vat_rates 
        WHERE id = %s AND is_active = true
        """
        
        try:
            result = execute_query(query, [vat_rate_id], fetch=True)
            if result and len(result) > 0:
                return Decimal(str(result[0]['rate_percentage']))
            return None
        except Exception as e:
            logger.error(f"Error getting VAT rate percentage: {e}")
            return None
    
    @staticmethod
    def calculate_eworker_expense(days: Decimal, daily_rate: Decimal) -> Decimal:
        """Calculate e-worker expense amount"""
        return (days * daily_rate).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    
    @staticmethod
    def calculate_mileage_expense(km: Decimal, rate_per_km: Decimal = Decimal('0.3708')) -> Decimal:
        """Calculate mileage expense amount"""
        return (km * rate_per_km).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    
    @staticmethod
    def get_irish_mileage_rate() -> Decimal:
        """Get current Irish Revenue mileage rate"""
        return Decimal('0.3708')  # 2024 rate - should be configurable
    
    @staticmethod
    def create_vat_rate(vat_rate: VATRate) -> Optional[str]:
        """Create a new VAT rate"""
        query = """
        INSERT INTO public.vat_rates 
        (country, rate_name, rate_percentage, description, is_active, effective_from, effective_until)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING id
        """
        
        params = [
            vat_rate.country,
            vat_rate.rate_name,
            vat_rate.rate_percentage,
            vat_rate.description,
            vat_rate.is_active,
            vat_rate.effective_from,
            vat_rate.effective_until
        ]
        
        try:
            result = execute_query(query, params)
            if result and len(result) > 0:
                return str(result[0][0])
            return None
        except Exception as e:
            logger.error(f"Error creating VAT rate: {e}")
            return None
    
    @staticmethod
    def create_expense_category(category: ExpenseCategory) -> Optional[str]:
        """Create a new expense category"""
        query = """
        INSERT INTO public.expense_categories 
        (category_name, category_type, default_vat_rate_id, supports_business_usage,
         default_business_usage, requires_receipt, description, is_active)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
        """
        
        params = [
            category.category_name,
            category.category_type,
            category.default_vat_rate_id,
            category.supports_business_usage,
            category.default_business_usage,
            category.requires_receipt,
            category.description,
            category.is_active
        ]
        
        try:
            result = execute_query(query, params)
            if result and len(result) > 0:
                return str(result[0][0])
            return None
        except Exception as e:
            logger.error(f"Error creating expense category: {e}")
            return None
    
    @staticmethod
    def get_vat_summary_for_period(
        company_id: str, 
        start_date: str, 
        end_date: str
    ) -> Dict[str, Decimal]:
        """Get VAT summary for a company in a period"""
        
        # Get sales VAT (from invoices)
        sales_query = """
        SELECT COALESCE(SUM(net_amount), 0) as total_sales,
               COALESCE(SUM(vat_amount), 0) as total_output_vat
        FROM public.invoices
        WHERE company_id = %s AND issue_date BETWEEN %s AND %s
        """
        
        # Get purchase VAT (from expenses with deductible amounts)
        purchase_query = """
        SELECT COALESCE(SUM(deductible_amount), 0) as total_purchases,
               COALESCE(SUM(vat_amount * business_usage_percentage / 100), 0) as total_input_vat
        FROM public.expenses
        WHERE company_id = %s AND expense_date BETWEEN %s AND %s
        """
        
        try:
            sales_result = execute_query(sales_query, [company_id, start_date, end_date])
            purchase_result = execute_query(purchase_query, [company_id, start_date, end_date])
            
            total_sales = Decimal(str(sales_result[0][0])) if sales_result else Decimal('0')
            total_output_vat = Decimal(str(sales_result[0][1])) if sales_result else Decimal('0')
            total_purchases = Decimal(str(purchase_result[0][0])) if purchase_result else Decimal('0')
            total_input_vat = Decimal(str(purchase_result[0][1])) if purchase_result else Decimal('0')
            
            net_vat_due = total_output_vat - total_input_vat
            
            return {
                'total_sales': total_sales,
                'total_output_vat': total_output_vat,
                'total_purchases': total_purchases,
                'total_input_vat': total_input_vat,
                'net_vat_due': net_vat_due
            }
            
        except Exception as e:
            logger.error(f"Error calculating VAT summary: {e}")
            return {
                'total_sales': Decimal('0'),
                'total_output_vat': Decimal('0'),
                'total_purchases': Decimal('0'),
                'total_input_vat': Decimal('0'),
                'net_vat_due': Decimal('0')
            }