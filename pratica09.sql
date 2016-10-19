/* pratica09.sql: Result Cache
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
  O objetivo desta pr�tica � demonstrar a feature RESULT CACHE, come�ando pela
  visualiza��o da sua configura��o, pelas funcionalidades da dbms_result_cache,
  as principais views de performance e finalmente o seu uso nas formas SQL
  query result cache e PL/SQL result cache.
  
  Al�m disso, vamos tamb�m testar outras t�cnicas de cache: fun��es 
  deterministicas e Scalar Subquery Caching.
*/

-- mostra par�metros relacionados
show parameter result_cache;

/*
  dbms_result_cache
 */
 
-- Estado atual do result cache
select dbms_result_cache.status from dual;

-- Relat�rio de uso
set serveroutput on
exec dbms_result_cache.memory_report(detailed => true);

-- detalhes sobre o uso da mem�ria
select *
  from v$result_cache_memory;

-- objetos que est�o em cache
select *
  from v$result_cache_objects;

-- objetos do usu�rio atual que est�o em cache
select *
  from v$result_cache_objects
 where creator_uid = uid; -- uid = user id

-- estat�sticas de uso do result cache
select *
  from v$result_cache_statistics;

/*
  SQL QUERY RESULT CACHE
 */

-- Veja o plano de execu��o da query a seguir
explain plan for
select o.customer_id,
       sum(oi.unit_price * oi.quantity) total_compras
  from oe.orders      o,
       oe.order_items oi
 where o.order_id = oi.order_id
 group by customer_id;
 
select plan_table_output
  from table(dbms_xplan.display);

-- Agora vamos rodar a query com result cache
select --+ RESULT_CACHE
       o.customer_id,
       sum(oi.unit_price * oi.quantity) total_compras
  from oe.orders      o,
       oe.order_items oi
 where o.order_id = oi.order_id
 group by customer_id;

-- Compare os planos
explain plan for
select --+ RESULT_CACHE
       o.customer_id,
       sum(oi.unit_price * oi.quantity) total_compras
  from oe.orders      o,
       oe.order_items oi
 where o.order_id = oi.order_id
 group by customer_id;

select plan_table_output
  from table(dbms_xplan.display);

-- Verificando que o objeto est� no cache
select *
  from v$result_cache_objects
 where creator_uid = uid; -- uid = user id

/*
  PL/SQL RESULT CACHE
 */

-- Executar como SYS do PDB
-- vamos precisar desta package para simular o processamento de uma fun��o
grant execute on dbms_lock to curso;
 
-- Esta fun��o gasta 1 segundo para cada chamada e retorna o valor de entrada
-- O objetivo � parecer uma fun��o "pesada"
create or replace function func_nocache(pval in number)
return number
as
begin
  dbms_lock.sleep(1);
  
  return pval;
end;
/

-- Este vai ser o nosso cursor de refer�ncia
select rownum id
  from dual connect by level <= 10;

-- Para cada linha do cursor de refer�ncia vamos chamar a fun��o uma vez
-- com o rownum como par�metro (valores de 1 a 10)
select rownum id, func_nocache(rownum)
  from dual connect by level <= 10;

-- � a mesma query, execute ela novamente... teve diferen�a no tempo?
select rownum id, func_nocache(rownum)
  from dual connect by level <= 10;

-- Agora a mesma fun��o est� sendo criada com a cl�usula result_cache
create or replace function func_cache(pval in number)
return number result_cache
as
begin
  dbms_lock.sleep(1);
  
  return pval;
end;
/

-- Executando a primeira vez... at� agora nenhuma diferen�a porque o resultado
-- da fun��o nova n�o est� no cache
select rownum id, func_cache(rownum)
  from dual connect by level <= 10;

-- Executando novamente, agora os resultados est�o em cache...
select rownum id, func_cache(rownum)
  from dual connect by level <= 10;

-- Limpeza do cache
exec dbms_result_cache.flush;

-- Zerado
select count(*)
  from v$result_cache_objects;

-- Al�m disso, se voc� executar a query acima novamente vai ver que ela estar�
-- "trabalhando" de novo

/*
  DETERMINISTIC
 */

-- Vamos come�ar criando uma tabela auxiliar de 10 linhas, mas com alguns
-- valores repetidos.
drop table tab_10_linhas;
create table tab_10_linhas as
select mod(rownum,4) linha from dual connect by level <= 10;

-- O script original tem 4 valores (divisor do rownum), mas fique a vontade
-- para experimentar outras possibilidades
select count(distinct linha) from tab_10_linhas;

-- Cria a mesma fun��o do exemplo anterior, mas com a propriedade
-- DETERMINISTIC.
create or replace function func_det(pval in number)
return number deterministic
as
begin
  dbms_lock.sleep(1);
  
  return pval;
end;
/

-------------------------------------------------
-- Executar os pr�ximos dois blocos no sqlplus --
-------------------------------------------------

-- Ativa exibi��o do tempo decorrido
set timing on
-- Tamanho do FETCH
set arraysize 15

-- Chama a fun��o n vezes... quantas?
select linha, func_det(linha)
  from tab_10_linhas;
  
-- Muda o tamanho do fetch para 2 linhas
set arraysize 2

-- Chama a fun��o n vezes... quantas?
select linha, func_det(linha)
  from tab_10_linhas;

-----------------------------------
----- fim do trecho SQL*Plus ------
-----------------------------------

/*
  SCALAR SUBQUERY CACHING
 */

-- Para demonstrar este recurso, poder�amos utilizar a mesma fun��o anterior
-- mas vamos usar a t�cnica de manter um contador de execu��es para ficar
-- mais claro.
drop table t8;
create table t8 as
select 1 cnt from dual where 1=0;

-- Tabela T8 s� tem um campo NUMBER
desc t8

-- Inicializa a tabela com o contador em zero
insert into t8 values(0);
commit;

-- A fun��o � a mesma: retorna o valor de entrada, por�m internamente
-- adicionamos o mecanismo de contador
create or replace function func1 (pnum in number)
return number
as
  -- Esta fun��o realiza uma transa��o independente do SELECT que chama ela
  pragma autonomous_transaction;
begin
  update t8 set cnt = cnt + 1;
  commit;
  
  return pnum;
end;
/

-- Uma chamada da fun��o
select func1(1) from dual;

-- Testando o contador
select cnt from t8;

-- Executando a fun��o para cada linha da tabela
select linha, func1(linha) 
  from tab_10_linhas;

-- 10 linhas, 10 chamadas... confere?
select cnt from t8;

-- Chamada com o mesmo valor
select linha, func1(1) 
  from tab_10_linhas;

-- Ainda assim, 10 chamadas
select cnt from t8;

-- Scalar Subquery Cache para um valor
select linha, (select func1(1) from dual) 
  from tab_10_linhas;

-- Quantas chamadas?
select cnt from t8;

-- Scalar Subquery Cache para v�rios valores
select linha, (select func1(linha) from dual) 
  from tab_10_linhas;

-- Quantas chamadas?
select cnt from t8;
