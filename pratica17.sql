/* pratica17.sql: Modelagem F�sica
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
  O objetivo desta pr�tica � demonstrar o impacto de altera��es na modelagem
  f�sica dos objetos.
*/

--------------------
-- INDEX COMPRESS --
--------------------

/*
  Neste cen�rio vamos criar uma tabela com dados artificiais para simular a
  compress�o de �ndices com diferentes ordens de coluna.
*/

drop table t;
create table t(pedido primary key, produto, cliente, dt_pedido) as
select rownum            pedido,
       mod(rownum, 1000) produto,
       mod(rownum, 100)  cliente,
       sysdate + mod(rownum, 100) dt_pedido
  from dual connect by level <= 1000000;
  
-- Cria��o dos �ndices
create index t_idx1 on t(pedido, produto, cliente);
create index t_idx2 on t(produto, cliente);
create index t_idx3 on t(produto, cliente, dt_pedido);
create index t_idx4 on t(cliente, produto, pedido);
create index t_idx5 on t(cliente);

-- Esta � uma tabela auxiliar que ser� utilizada pela package a seguir
create table idx_stats as
select * from index_stats;

-- Esta package automatiza o processo de an�lise e compacta��o dos �ndices
--
-- A rotina idx_compress_analyze calcula o prefixo ideal e a compacta��o
-- estimada.
--
-- A rotina idx_compress_execute executa a compacta��o recomendada para todos
-- os �ndices cujo pctsave for maior igual ao seu par�metro (default 10)
--
create or replace package pkg_idx_compress as

  procedure idx_compress_analyze;
  procedure idx_compress_execute(pctsave number default 10);

end pkg_idx_compress;
/

create or replace package body pkg_idx_compress as

procedure idx_compress_analyze as
begin
  for r in (select user as owner,
                   index_name
              from user_indexes)
  loop
    execute immediate 'analyze index ' || r.owner || '.' || r.index_name || ' validate structure';
    insert into idx_stats select * from index_stats;
  end loop;
  commit;
 
end idx_compress_analyze;

procedure idx_compress_execute(pctsave number default 10) as
begin
  for r in (select user as owner, name, opt_cmpr_count from idx_stats where opt_cmpr_pctsave >= pctsave)
  loop
    execute immediate 'alter index ' || r.owner || '.' || r.name || ' rebuild compress ' || r.opt_cmpr_count;
  end loop;
 
end idx_compress_execute;

end pkg_idx_compress;
/

-- �ndices antes da compacta��o
select table_name, index_name, bytes / 1024 as kbytes, compression
  from user_indexes  ui,
       user_segments us
 where ui.index_name = us.segment_name;

-- An�lise
begin
  pkg_idx_compress.idx_compress_analyze;
end;
/

-- Resultado da an�lise e estimativas
select user as owner,
       name as index_name,
       opt_cmpr_count,
       opt_cmpr_pctsave
  from idx_stats;
  
-- Executa compacta��o
begin
  pkg_idx_compress.idx_compress_execute;
end;
/

-- Resultado
select table_name, index_name, bytes / 1024 as kbytes, compression
  from user_indexes  ui,
       user_segments us
 where ui.index_name = us.segment_name;
 
--------------------
-- COMPRESSED IOT --
--------------------

-- Estamos usando uma pk com ordem at�pica apenas para demonstrar a taxa de
-- compacta��o
drop table t2;
create table t2(pedido, produto, cliente, dt_pedido, constraint pk_t2 primary key(cliente, produto, pedido))
organization index as select * from t;

-- Observe o tamanho
select table_name, index_name, bytes / 1024 as kbytes, compression
  from user_indexes  ui,
       user_segments us
 where ui.index_name = us.segment_name
   and ui.table_name = 'T2';

-- Lembrando que a PK n�o tem apenas o �ndice, mas tamb�m os dados
analyze index pk_t2 validate structure;

-- Estimativa de compress�o e n�mero ideal de colunas
select name, opt_cmpr_count, opt_cmpr_pctsave from index_stats;

-- Para compactar, usamos o alter table move ao inv�s de alter index rebuild
-- mas a sintaxe do compress continua sendo COMPRESS [n�mero de colunas]
alter table t2 move online compress 2;

-- Compare o tamanho
select table_name, index_name, bytes / 1024 as kbytes, compression
  from user_indexes  ui,
       user_segments us
 where ui.index_name = us.segment_name
   and ui.table_name = 'T2';

-------------------------------------
-- MATERIALIZED VIEW QUERY REWRITE --
-------------------------------------

-- Executar como SYSTEM do PDB
grant global query rewrite to curso;
grant select on sh.sales to curso;
grant select on sh.times to curso;

-- Veja o plano de execu��o desta consulta
explain plan for
 SELECT t.calendar_month_desc, SUM(s.amount_sold) AS dollars
   FROM sh.sales s, sh.times t 
  WHERE s.time_id = t.time_id
  GROUP BY t.calendar_month_desc;

select *
  from table(dbms_xplan.display);

-- Criamos uma view materializada com query rewrite para esta consulta
drop materialized view cal_month_sales_mv;
CREATE MATERIALIZED VIEW cal_month_sales_mv
 ENABLE QUERY REWRITE AS
 SELECT t.calendar_month_desc, SUM(s.amount_sold) AS dollars
   FROM sh.sales s, sh.times t 
  WHERE s.time_id = t.time_id
  GROUP BY t.calendar_month_desc;

-- Compare o plano
explain plan for
SELECT t.calendar_month_desc, SUM(s.amount_sold)
FROM sh.sales s, sh.times t WHERE s.time_id = t.time_id
GROUP BY t.calendar_month_desc;

select *
  from table(dbms_xplan.display);
  
-- https://docs.oracle.com/database/121/DWHSG/qrbasic.htm#DWHSG0184

--------------------------------
-- COMPRESSION e PARTITIONING --
--------------------------------

/*
  Para demonstrar os recursos de compress�o e particionamento, n�s vamos criar 
  tr�s tabelas: uma tabela com compress�o ativada, uma tabela com compress�o e
  particionamento (com diferentes n�veis de compress�o para cada parti��o) e
  uma tabela sem compress�o.
*/

-- Compress�o b�sica
drop table test_tab_1;
create table test_tab_1 (
  id            number(10)    not null,
  description   varchar2(50)  not null,
  created_date  date          not null
) row store compress;

-- Definindo n�veis diferentes de compress�o para cada parti��o
drop table test_tab_2;
create table test_tab_2 (
  id            number(10)    not null,
  description   varchar2(50)  not null,
  created_date  date          not null
)
partition by range (created_date) (
  partition test_tab_q1 values less than (to_date('01/04/2008', 'DD/MM/YYYY')) row store compress,
  partition test_tab_q2 values less than (to_date('01/07/2008', 'DD/MM/YYYY')) row store compress basic,
  partition test_tab_q3 values less than (to_date('01/10/2008', 'DD/MM/YYYY')) row store compress advanced,
  partition test_tab_q4 values less than (maxvalue) nocompress
);

-- Tabela sem compress�o, tamb�m ser� a nossa fonte de dados
--
-- Repare que as oportunidades para compress�o nesta tabela s�o a repeti��o da
-- descri��o e as datas.
drop table t_nocompress;
create table t_nocompress as
select rownum id, 
       'descricao ' || mod(rownum, 10) description, 
       to_date('01/01/2008', 'DD/MM/YYYY') + trunc(dbms_random.value(0,3600)) created_date
  from dual connect by level <= 1000000;

-- distribui��o de datas
select created_date, count(*)
  from t_nocompress
 group by created_date;

-- Visualizando a compress�o por tabela...
select table_name, compression, compress_for 
  from user_tables
 where table_name in ('TEST_TAB_1', 'TEST_TAB_2', 'T_NOCOMPRESS');

-- E por parti��o
select table_name, partition_name, compression, compress_for
  from user_tab_partitions
 where table_name in ('TEST_TAB_1', 'TEST_TAB_2', 'T_NOCOMPRESS');
 
 -- Estamos fazendo um direct path insert para que os dados sejam comprimidos
 insert /*+ append */ into test_tab_1
 select * from t_nocompress;
 
 -- Estamos fazendo um direct path insert para que os dados sejam comprimidos
 insert /*+ append */ into test_tab_2
 select * from t_nocompress;

commit;

-- Compara��o de tamanho
select segment_name, partition_name, segment_type, bytes / 1024 kbytes
  from user_segments
 where segment_name in ('TEST_TAB_1', 'TEST_TAB_2', 'T_NOCOMPRESS', 
                        'TEST_TAB_Q1', 'TEST_TAB_Q2', 'TEST_TAB_Q3', 
                        'TEST_TAB_Q4');

begin
  dbms_stats.gather_table_stats(user, 'TEST_TAB_1');
  dbms_stats.gather_table_stats(user, 'TEST_TAB_2');
  dbms_stats.gather_table_stats(user, 'T_NOCOMPRESS');
end;
/

-- Agora compare o plano e custo do acesso em cada tabela

-- Sem compress�o
explain plan for
select *
  from t_nocompress
 where created_date between to_date('01/05/2008', 'DD/MM/YYYY')
                        and to_date('30/05/2008', 'DD/MM/YYYY');
 
 select *
  from table(dbms_xplan.display);

-- Com compress�o
explain plan for
select *
  from test_tab_1
 where created_date between to_date('01/05/2008', 'DD/MM/YYYY')
                        and to_date('30/05/2008', 'DD/MM/YYYY');
 
 select *
  from table(dbms_xplan.display);

-- Com compress�o e particionamento
explain plan for
select *
  from test_tab_2
 where created_date between to_date('01/05/2008', 'DD/MM/YYYY')
                        and to_date('30/05/2008', 'DD/MM/YYYY');
 
 select *
  from table(dbms_xplan.display);
