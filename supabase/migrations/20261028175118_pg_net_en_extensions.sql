-- pg_net se instaló en public; el avisador pide moverlo. Sus funciones siguen en el esquema net.
drop extension pg_net;
create extension pg_net with schema extensions;
