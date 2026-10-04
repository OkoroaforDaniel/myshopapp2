from pydantic import BaseModel, Field
from typing import List, Optional

class CartItem(BaseModel):
    product_id: Optional[str] = None
    product_name: str
    size: str = "Medium"
    qty: int = Field(ge=1, default=1)
    unit_price: float = 0

class CheckoutRequest(BaseModel):
    customer_name: str
    customer_email: str
    phone: str = ""
    address: str = ""
    city: str = ""
    postcode: str = ""
    fulfilment: str = "Delivery"
    payment_method: str = "Pay on delivery"
    coupon_code: str = ""
    free_item: str = ""
    paystack_reference: str = ""  # set when paid online via Paystack
    items: List[CartItem]

class ProfileUpsert(BaseModel):
    email: str
    full_name: str = ""
    avatar_url: str = ""

class CartSyncItem(BaseModel):
    product_id: Optional[str] = None
    product_name: str
    size: str = "Medium"
    qty: int = Field(ge=0, default=1)
    unit_price: float = 0
    image_url: str = ""

class CartSyncRequest(BaseModel):
    items: List[CartSyncItem] = []
    coupon_code: str = ""
    fulfilment: str = "Delivery"

class SignupRequest(BaseModel):
    email: str
    password: str
    full_name: str = ""

class LoginRequest(BaseModel):
    email: str
    password: str = ""

