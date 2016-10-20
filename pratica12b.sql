/* pratica12b.sql: Estatísticas II
 * Copyright (C) 2016 Daniela Petruzalek
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

-- Verifica a preferência global de tabela temporária
select dbms_stats.get_prefs('GLOBAL_TEMP_TABLE_STATS') from dual;

-- Configura como estatística compartilhada
begin
  dbms_stats.set_global_prefs (
    pname   => 'GLOBAL_TEMP_TABLE_STATS',
    pvalue  => 'SHARED');
end;
/

-- Configura como estatística por sessão
begin
  dbms_stats.set_global_prefs (
    pname   => 'GLOBAL_TEMP_TABLE_STATS',
    pvalue  => 'SESSION');
end;
/

truncate table gtt1;
drop table gtt1;
create global temporary table gtt1 (
  id number,
  description varchar2(20)
) on commit PRESERVE rows;


-- Configura estatísticas de GTT como compartilhadas
begin
  dbms_stats.set_global_prefs (
    pname   => 'GLOBAL_TEMP_TABLE_STATS',
    pvalue  => 'SHARED');
end;
/

-- Insere alguns dados e coleta estatísticas
insert into gtt1
select level, 'description'
from   dual
connect by level <= 100;

exec dbms_stats.gather_table_stats('CURSO','GTT1');

-- O count abaixo vai depender do tipo da GTT1:
-- on commit delete rows   = 0
-- on commit preserve rows = 100
select count(*) from gtt1;

-- Existe um commit implicito no dbms_stats quando o GLOBAL_TEMP_TABLE_STATS é
-- configurado como SHARED

-- Display the statistics information and scope.
column table_name format a20

select table_name, num_rows, scope
from   dba_tab_statistics
where  owner = user
and    table_name = 'GTT1';

-- Reset the GTT statistics preference to SESSION.
begin
  dbms_stats.set_global_prefs (
    pname   => 'GLOBAL_TEMP_TABLE_STATS',
    pvalue  => 'SESSION');
end;
/

insert into gtt1
select level, 'description'
from   dual
connect by level <= 1000;
commit;

exec dbms_stats.gather_table_stats(user,'GTT1');

-- O count abaixo vai depender do tipo da GTT1:
-- on commit delete rows   = 1000
-- on commit preserve rows = 1100
select count(*) from gtt1;

-- Existe um commit implicito no dbms_stats quando o GLOBAL_TEMP_TABLE_STATS é
-- configurado como SHARED

-- Exibe estatísticas e informação de escopo
column table_name format a20

select table_name, num_rows, scope
from   dba_tab_statistics
where  owner = user
and    table_name = 'GTT1';

---------------------------------------------
-- Fazer a consulta abaixo em outra sessão --
---------------------------------------------

-- Exibe estatísticas e informação de escopo
column table_name format a20

select table_name, num_rows, scope
from   dba_tab_statistics
where  owner = user
and    table_name = 'GTT1';

-- Referência
-- https://oracle-base.com/articles/12c/session-private-statistics-for-global-temporary-tables-12cr1