from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    SUPABASE_URL: str = ""
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_SERVICE_KEY: str = ""
    SUPABASE_JWT_SECRET: str = ""
    MAILGUN_API_KEY: str = ""
    MAILGUN_DOMAIN: str = ""
    MAILGUN_FROM: str = "Tandoori Pizza PH <orders@example.com>"
    SHOP_OWNER_EMAIL: str = ""
    FRONTEND_URL: str = "http://localhost:3000"
    GOOGLE_CLIENT_ID: str = ""
    # Paystack (Nigeria cards / transfer / USSD)
    PAYSTACK_SECRET_KEY: str = ""
    PAYSTACK_PUBLIC_KEY: str = ""
    # WhatsApp alerts via CallMeBot (free, no approval) — see README
    WHATSAPP_PHONE: str = ""   # e.g. 2348034444343 (owner number, no +)
    WHATSAPP_APIKEY: str = ""  # CallMeBot apikey

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()

