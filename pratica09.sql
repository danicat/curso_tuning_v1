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
  O objetivo desta prática é demonstrar a feature RESULT CACHE, começando pela
  visualização da sua configuração, pelas funcionalidades da dbms_result_cache,
  as principais views de performance e finalmente o seu uso nas formas SQL
  query result cache e PL/SQL result cache.
  
  Além disso, vamos também testar outras técnicas de cache: funções 
  deterministicas e Scalar Subquery Caching.
*/

-- mostra parâmetros relacionados
show parameter result_cache;

/*
  dbms_result_cache
 */
 
-- Estado atual do result cache
select dbms_result_cache.status from dual;

-- Relatório de uso
set serveroutput on
exec dbms_result_cache.memory_report(detailed => true);

-- detalhes sobre o uso da memória
select *
  from v$result_cache_memory;

-- objetos que estão em cache
select *
  from v$result_cache_objects;

-- objetos do usuário atual que estão em cache
select *
  from v$result_cache_objects
 where creator_uid = uid; -- uid = user id

-- estatísticas de uso do result cache
select *
  from v$result_cache_statistics;

/*
  SQL QUERY RESULT CACHE
 */

-- Veja o plano de execução da query a seguir
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

-- Verificando que o objeto está no cache
select *
  from v$result_cache_objects
 where creator_uid = uid; -- uid = user id

/*
  PL/SQL RESULT CACHE
 */

-- Executar como SYS do PDB
-- vamos precisar desta package para simular o processamento de uma função
grant execute on dbms_lock to curso;
 
-- Esta função gasta 1 segundo para cada chamada e retorna o valor de entrada
-- O objetivo é parecer uma função "pesada"
create or replace function func_nocache(pval in number)
return number
as
begin
  dbms_lock.sleep(1);
  
  return pval;
end;
/

-- Este vai ser o nosso cursor de referência
select rownum id
  from dual connect by level <= 10;

-- Para cada linha do cursor de referência vamos chamar a função uma vez
-- com o rownum como parâmetro (valores de 1 a 10)
select rownum id, func_nocache(rownum)
  from dual connect by level <= 10;

-- É a mesma query, execute ela novamente... teve diferença no tempo?
select rownum id, func_nocache(rownum)
  from dual connect by level <= 10;

-- Agora a mesma função está sendo criada com a cláusula result_cache
create or replace function func_cache(pval in number)
return number result_cache
as
begin
  dbms_lock.sleep(1);
  
  return pval;
end;
/

-- Executando a primeira vez... até agora nenhuma diferença porque o resultado
-- da função nova não está no cache
select rownum id, func_cache(rownum)
  from dual connect by level <= 10;

-- Executando novamente, agora os resultados estão em cache...
select rownum id, func_cache(rownum)
  from dual connect by level <= 10;

-- Limpeza do cache
exec dbms_result_cache.flush;

-- Zerado
select count(*)
  from v$result_cache_objects;

-- Além disso, se você executar a query acima novamente vai ver que ela estará
-- "trabalhando" de novo

/*
  DETERMINISTIC
 */

-- Vamos começar criando uma tabela auxiliar de 10 linhas, mas com alguns
-- valores repetidos.
drop table tab_10_linhas;
create table tab_10_linhas as
select mod(rownum,4) linha from dual connect by level <= 10;

-- O script original tem 4 valores (divisor do rownum), mas fique a vontade
-- para experimentar outras possibilidades
select count(distinct linha) from tab_10_linhas;

-- Cria a mesma função do exemplo anterior, mas com a propriedade
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
-- Executar os próximos dois blocos no sqlplus --
-------------------------------------------------

-- Ativa exibição do tempo decorrido
set timing on
-- Tamanho do FETCH
set arraysize 15

-- Chama a função n vezes... quantas?
select linha, func_det(linha)
  from tab_10_linhas;
  
-- Muda o tamanho do fetch para 2 linhas
set arraysize 2

-- Chama a função n vezes... quantas?
select linha, func_det(linha)
  from tab_10_linhas;

-----------------------------------
----- fim do trecho SQL*Plus ------
-----------------------------------

/*
  SCALAR SUBQUERY CACHING
 */

-- Para demonstrar este recurso, poderíamos utilizar a mesma função anterior
-- mas vamos usar a técnica de manter um contador de execuções para ficar
-- mais claro.
drop table t8;
create table t8 as
select 1 cnt from dual where 1=0;

-- Tabela T8 só tem um campo NUMBER
desc t8

-- Inicializa a tabela com o contador em zero
insert into t8 values(0);
commit;

-- A função é a mesma: retorna o valor de entrada, porém internamente
-- adicionamos o mecanismo de contador
create or replace function func1 (pnum in number)
return number
as
  -- Esta função realiza uma transação independente do SELECT que chama ela
  pragma autonomous_transaction;
begin
  update t8 set cnt = cnt + 1;
  commit;
  
  return pnum;
end;
/

-- Uma chamada da função
select func1(1) from dual;

-- Testando o contador
select cnt from t8;

-- Executando a função para cada linha da tabela
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

-- Scalar Subquery Cache para vários valores
select linha, (select func1(linha) from dual) 
  from tab_10_linhas;

-- Quantas chamadas?
select cnt from t8;
