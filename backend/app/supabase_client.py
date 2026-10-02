from supabase import create_client, Client
from .config import settings

_supabase_anon: Client | None = None
_supabase_admin: Client | None = None

def get_supabase_anon() -> Client:
    global _supabase_anon
    if _supabase_anon is None:
        _supabase_anon = create_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)
    return _supabase_anon

def get_supabase_admin() -> Client:
    """Service-role client — use ONLY on backend for inserts."""
    global _supabase_admin
    if _supabase_admin is None:
        key = settings.SUPABASE_SERVICE_KEY or settings.SUPABASE_ANON_KEY
        _supabase_admin = create_client(settings.SUPABASE_URL, key)
    return _supabase_admin
