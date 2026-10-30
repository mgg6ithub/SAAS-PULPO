-- iPultec (IPT-007): los mantenimientos de cada componente también se ven en vivo (RLS decide qué llega).
alter publication supabase_realtime add table public.planes_mantenimiento;
