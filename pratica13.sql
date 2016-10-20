/* pratica13.sql: Compartilhamento de Cursores
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

/*
  O objetivo desta prática é complementar a nossa conversa sobre padrões
  de codificação com algumas informações adicionas sobre compartilhamento
  de cursores
*/

drop table employees;
create table employees as
select e.* 
  from hr.employees e, (select rownum from dual connect by level <= 10000);

-- 1 milhão de linhas
select count(*) from employees;

select department_id, count(*)
  from employees
 group by department_id
 order by 2 desc;

-- vamos dividir aleatoriamente pela metade o departamento 10
update employees
   set department_id = case when mod(trunc(dbms_random.value * 2),2) = 0
                            then 5
                            else 15
                            end
 where department_id = 10;

update employees
   set department_id = 50
 where department_id in (80,100,30,90,20);

commit;

select department_id, count(*)
  from employees
 group by department_id
 order by 2 desc;


drop index idx_emp_depto;
create index idx_emp_depto on employees(department_id);

exec dbms_stats.gather_table_stats(user,'EMPLOYEES', method_opt => 'FOR ALL COLUMNS SIZE AUTO');

alter system flush shared_pool;

-- Execute as seguintes querys
select /*bloco1*/ count(*), max(employee_id) from employees where department_id = 50;
select /*bloco1*/ count(*), max(employee_id) from employees where department_id = 100;
select /*bloco1*/ count(*), max(employee_id) from employees where department_id = 5;

-- Observe que mesmo sendo exatamente a mesma query, apenas com valores
-- distintos, o Oracle interpretou como três querys diferentes:
select sql_id, sql_text, plan_hash_value, fetches, executions, loads, loaded_versions
  from v$sql
 where sql_text like 'select /*bloco1*/%';

-- No entanto, observe atentamente ao PLAN_HASH_VALUE. Duas querys mesmo sendo
-- diferentes, utilizaram o mesmo plano. Duvida? :) Confira os planos:

explain plan for
select /*bloco1*/ count(*), max(employee_id) 
  from employees 
 where department_id = 5;
 
select * from table(dbms_xplan.display);

-- Agora vamos executar a mesma consulta com binds
select /*bloco1*/ count(*), max(employee_id) from employees where department_id = :depto;

-- Repare no flag IS_BIND_SENSITIVE
select sql_id, child_number, sql_text, plan_hash_value, is_bind_sensitive, is_bind_aware, buffer_gets 
  from v$sql
 where sql_text like 'select /*bloco1*/%';


-------------------------------------
-- Executar esta etapa do SQL*Plus --
-------------------------------------

var depto number;
exec :depto := 5;
select /*bloco1*/ count(*), max(employee_id) from employees where department_id = :depto;
exec :depto := 50;
select /*bloco1*/ count(*), max(employee_id) from employees where department_id = :depto;

------------------------------
-- Retorne ao SQL Developer --
------------------------------

-- Repare no flag IS_BIND_SENSITIVE
select sql_id, child_number, sql_text, plan_hash_value, is_bind_sensitive, is_bind_aware, buffer_gets 
  from v$sql
 where sql_text like 'select /*bloco1*/%';

-- Observe que para a mesma query cada child_number tem um plano diferente
select *
  from v$sql_plan
 where sql_id = 'fkaycpxt6xqfx';

-- O segundo parâmetro é o child_number
select * from table(dbms_xplan.display_cursor('fkaycpxt6xqfx', 1));