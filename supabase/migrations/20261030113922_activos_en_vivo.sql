-- iPultec (IPT-006): los activos también se ven en vivo entre usuarios de la empresa (RLS decide qué llega).
alter publication supabase_realtime add table public.activos;
