/* pratica12.sql: Estat�sticas
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
  O objetivo desta pr�tica � mostrar os principais tipos de estat�stica que
  o CBO utiliza para a tomada de decis�o.
*/

/*
  Para come�ar, vamos ver as principais views. Lembrando que views all_* e
  dba_* mostram todos os objetos, enquanto as views user_* mostram apenas os
  objetos do usu�rio atual.
 */

-- Estat�sticas de tabelas
select * from all_tab_statistics;
select * from user_tab_statistics;

-- Estat�sticas de �ndices
select * from all_ind_statistics;
select * from user_ind_statistics;

-- Estat�sticas de colunas
select * from all_tab_col_statistics;
select * from user_tab_col_statistics;

-- Algumas consultas para ilustrar:

-- Estat�sticas de uma tabela
select num_rows, avg_row_len, blocks, last_analyzed
from   dba_tab_statistics
where  owner='SH'
and    table_name='CUSTOMERS';

-- M�tricas de �ndices
select index_name, blevel, leaf_blocks as "LEAFBLK", distinct_keys as "DIST_KEY",
       avg_leaf_blocks_per_key as "LEAFBLK_PER_KEY",
       avg_data_blocks_per_key as "DATABLK_PER_KEY"
from   dba_ind_statistics
where  owner = 'SH'
and    index_name in ('CUST_LNAME_IX','CUSTOMERS_PK');

-----------------------
-- CLUSTERING FACTOR --
-----------------------

/*
  Clustering Factor � uma estat�stica de �ndices que mede a proximidade f�sica
  das linhas em rela��o a um valor do �ndice. Um valor baixo de clustering
  factor indica para o otimizador que valores pr�ximos da chave est�o pr�ximos 
  uns aos outros fisicamente, e favorece que o otimizador escolha o acesso por
  �ndice.
  
  Um clustering factor que � pr�ximo do n�mero de *blocos* da tabela indica que
  as linhas est�o fisicamente ordenadas nos blocos da tabela pela chave do 
  �ndice.
  
  Um clustering factor que � pr�ximo do n�mero de "linhas" da tabela indica que
  as linhas est�o espalhadas aleatoriamente nos blocos da tabela, com rela��o
  � chave do �ndice.
  
  O clustering factor � uma propriedade do �ndice e n�o da tabela, pois para
  medir o grau de "ordena��o" precisamos de uma refer�ncia - que � a chave do
  �ndice. Dois indices na mesma tabela podem ter clustering factors 
  completamente diferentes.
  
  Por exemplo: uma tabela de funcion�rio, com colunas nome e sobrenome, e dois
  �ndices, um em cada coluna. Se a tabela f�sica estiver ordenada por nome,
  o �ndice no nome vai ter um baixo clustering factor e o �ndice no sobrenome
  vai ter um alto clustering factor. Se o dado f�sico estiver ordenado por
  sobrenome, a situa��o se inverte.
  
  Logo, na maioria dos casos voc� n�o vai se preocupar em otimizar o clustering
  factor, ele � apenas uma consequencia da estrutura atual e mais uma m�trica
  para o otimizador tomar decis�es.
  
  Abaixo, vamos ver como o clustering factor de um �ndice pode influenciar a
  decis�o do CBO:
 */

-- Para este exemplo vamos utilizar a tabela SH.CUSTOMERS
-- Repare no n�mero de linhas e n�mero de blocos
select table_name, num_rows, blocks
  from all_tables
 where table_name='CUSTOMERS'
   and owner = 'SH';

-- Vamos criar um �ndice na coluna cust_last_name
create index customers_last_name_idx on sh.customers(cust_last_name);

-- Observe o clustering factor... ele est� mais pr�ximo do n�mero de blocos
-- ou do n�mero de linhas?
select index_name, blevel, leaf_blocks, clustering_factor
from   user_indexes
where  table_name = 'CUSTOMERS'
and    index_name = 'CUSTOMERS_LAST_NAME_IDX';

-- Embora numericamente ele esteja mais perto do n�mero de blocos do que do
-- n�mero de linhas, ele � aproximadamente 8x maior que o n�mero de blocos
-- sugerindo um grau de desordena��o

-- Vamos criar agora uma tabela com as linhas ordenadas por cust_last_name
drop table customers3 purge;
create table customers3 as 
 select * 
   from sh.customers 
  order by cust_last_name;

-- Coleta de estat�sticas da tabela
exec dbms_stats.gather_table_stats(user,'CUSTOMERS3');

-- Conferindo
select table_name, num_rows, blocks
  from user_tables
 where table_name='CUSTOMERS3';

-- Mesmo �ndice, na nova tabela
create index customers3_last_name_idx on customers3(cust_last_name);

-- Repare o clustering_factor... compare com o �ndice na tabela desordenada
select index_name, blevel, leaf_blocks, clustering_factor
  from user_indexes
 where table_name = 'CUSTOMERS3'
   and index_name = 'CUSTOMERS3_LAST_NAME_IDX';

-- Uma consulta
select cust_first_name, cust_last_name
  from sh.customers
 where cust_last_name between 'Puleo' and 'Quinn';

-- Qual � o plano?
select * from table(dbms_xplan.display_cursor());

-- Mesma consulta, agora na tabela ordenada
select cust_first_name, cust_last_name
  from customers3
 where cust_last_name between 'Puleo' and 'Quinn';

-- Compare os planos... e o custo?
select * from table(dbms_xplan.display_cursor());

-- E se n�s for�assemos o acesso por �ndice?
select /*+ index (Customers CUSTOMERS_LAST_NAME_IDX) */ 
       cust_first_name, 
       cust_last_name 
  from sh.customers 
 where cust_last_name between 'Puleo' and 'Quinn';

-- Compare o custo
select * from table(dbms_xplan.display_cursor());

/*
  Coleta de estat�sticas
 */

-- Para uma tabela
exec dbms_stats.gather_table_stats('HR','EMPLOYEES');

select index_name
  from all_indexes
 where owner = 'HR'
   and table_name = 'EMPLOYEES';

-- De um �ndice isolado
exec dbms_stats.gather_index_stats('HR','EMP_NAME_IX');

-- Do esquema todo
exec dbms_stats.gather_schema_stats('HR');

-- De todos os esquemas
exec dbms_stats.gather_database_stats;

-- Estat�sticas da tabela agora
select num_rows, empty_blocks, avg_row_len, blocks, last_analyzed
  from dba_tab_statistics d
 where owner='HR'
   and table_name='EMPLOYEES';

-- Estat�sticas de coluna
select column_name, 
       num_distinct,
       low_value,
       high_value,
       density,
       num_nulls,
       num_buckets,
       histogram
  from dba_tab_col_statistics d
 where owner='HR'
   and table_name='EMPLOYEES';

-- Esta fun��o vai nos ajudar a entender as colunas HIGH_VALUE e LOW_VALUE
-- da view acima
create or replace function raw_to_num(i_raw raw) 
return number 
as 
    m_n number; 
begin
    dbms_stats.convert_raw_value(i_raw,m_n); 
    return m_n; 
end; 
/     

-- A dbms_stats tem uma procedure de convers�o para cada tipo de representa��o
-- interna. Os tipos de dados varchar, number, float e date s�o convertidos com 
-- varia��es da procedure dbms_stats.convert_raw_value [overload]
--
-- Existem duas procedures extras para nvarchar e rowid:
-- dbms_stats.convert_raw_value_nvarchar
-- dbms_stats.convert_raw_value_rowid

select column_name, 
       raw_to_num(low_value)  low_value,
       raw_to_num(high_value) high_value,
       density,
       num_nulls,
       num_distinct,
       num_buckets,
       histogram
  from dba_tab_col_statistics d
 where owner='HR'
   and table_name='EMPLOYEES'
   and column_name in ('SALARY','EMPLOYEE_ID','DEPARTMENT_ID');

/*
  Histogramas
 */

-- A cria��o de histogramas n�s comandamos com o par�metro method_opt:
exec dbms_stats.gather_table_stats('HR','EMPLOYEES',method_opt => 'FOR ALL COLUMNS SIZE AUTO');

select column_name, num_distinct, num_buckets, histogram
  from dba_tab_col_statistics
 where owner = 'HR'
   and table_name = 'EMPLOYEES'
   and histogram != 'NONE';

-- O par�metro size indica o tamanho do bucket
-- e a rela��o entre o tamanho do bucket e o n�mero de distintos � o que
-- determina o tipo de histograma
exec dbms_stats.gather_table_stats('HR','EMPLOYEES',method_opt => 'FOR COLUMNS EMPLOYEE_ID SIZE 10');

select column_name, num_distinct, num_buckets, histogram
  from dba_tab_col_statistics
 where owner = 'HR'
   and table_name = 'EMPLOYEES'
   and histogram != 'NONE';

-- O tipo de histograma escolhido depende do perfil do dado. Neste caso, a
-- distribui��o do DEPARTMENT_ID favorece a cria��o do histograma TOP-FREQUENCY
exec dbms_stats.gather_table_stats('HR','EMPLOYEES',method_opt => 'FOR COLUMNS DEPARTMENT_ID SIZE 5');

-- De modo geral n�s n�o precisamos controlar a cria��o de histogramas, o Oracle
-- decide automaticamente de acordo com o perfil dos dados, mas em situa��es
-- espec�ficas podemos for�ar a sua cria��o conforme a estrat�gia mostrada acima

/*
  Estat�sticas estendidas
 */
 
/*
  Grupos de colunas
 */

set serveroutput on

-- Cria estat�sticas para um grupo de colunas e retorna o nome do grupo
declare
  l_cg_name varchar2(30);
begin
  l_cg_name := dbms_stats.create_extended_stats(ownname   => 'SCOTT',
                                                tabname   => 'EMP',
                                                extension => '(JOB,DEPTNO)');
  dbms_output.put_line('l_cg_name=' || l_cg_name);
end;
/

-- Outra forma de ver o nome do grupo
select dbms_stats.show_extended_stats_name(ownname   => 'SCOTT',
                                           tabname   => 'EMP',
                                           extension => '(JOB,DEPTNO)') as cg_name
from dual;

-- Para deletar o grupo
begin
  dbms_stats.drop_extended_stats(ownname   => 'SCOTT',
                                 tabname   => 'EMP',
                                 extension => '(JOB,DEPTNO)');
end;
/

-- A coleta com method_opt autom�tico inclui coleta para grupos:
begin
  dbms_stats.gather_table_stats(
    'SCOTT',
    'EMP',
    method_opt => 'for all columns size auto');
end;
/

-- Voc� tamb�m pode especificar um grupo que ainda n�o existe e ele ser�
-- criado automaticamente para voc�
begin
  dbms_stats.gather_table_stats(
    'SCOTT',
    'EMP',
    method_opt => 'for columns (job,mgr)');
end;
/

column extension format a30

-- Extens�es atuais
select extension_name, extension
from   dba_stat_extensions
where  table_name = 'EMP';

-- As estat�sticas estendidas s�o consideradas "colunas" na *_tab_col_statistics
select e.extension col_group,
       t.num_distinct,
       t.histogram
from   dba_stat_extensions e,
       dba_tab_col_statistics t 
where  e.extension_name=t.column_name
and    t.table_name = 'EMP';

/*
  Express�es
 */

declare
  l_cg_name varchar2(30);
begin
  -- Explicitly created.
  l_cg_name := dbms_stats.create_extended_stats(ownname   => 'SCOTT',
                                                tabname   => 'EMP',
                                                extension => '(LOWER(ENAME))');

  -- Implicitly created.
  dbms_stats.gather_table_stats(
    'SCOTT',
    'EMP',
    method_opt => 'for columns (upper(ename))');
end;
/

begin
  dbms_stats.gather_table_stats(
    'SCOTT',
    'EMP',
    method_opt => 'for all columns size auto');
end;
/

select extension_name, extension
from   dba_stat_extensions
where  table_name = 'EMP';

column col_group format a30

select e.extension col_group,
       t.num_distinct,
       t.histogram
from   dba_stat_extensions e,
       dba_tab_col_statistics t 
where  e.extension_name=t.column_name
and    t.table_name = 'EMP';

/*
  Estat�sticas de Sistema
  
  Estat�sticas de sistema s�o as estat�sticas que dizem para o Oracle o que
  ele pode esperar em termos de tempo de resposta e poder de processamento do
  hardware instalado.
 */

-- Este comando deleta os valores atuais, retornando para o padr�o
exec dbms_stats.delete_system_stats;

-- Estat�sticas atuais
select * from sys.aux_stats$;

-- Coletando estat�sticas NOWORKLOAD
exec dbms_stats.gather_system_stats; 

select * from sys.aux_stats$;

-- Coletando estat�sticas de intervalo (INTERVAL)

-- Manualmente
exec dbms_stats.gather_system_stats('start');
exec dbms_stats.gather_system_stats('stop');

-- Automaticamente, par�metro interval em minutos
exec DBMS_STATS.gather_system_stats('interval', interval => 1); 
 
-- No modo interval, o Oracle vai monitorar tudo que acontece no sistema
-- para tentar determinar os tempos de resposta dele. Se o workload n�o
-- for significativo, pode ser que ele n�o ache os valores corretos e fique
-- sub-dimensionado.

-- Para simular uma carga, vamos utilizar uma procedure de calibra��o de I/O

--------------------------------------
-- Troque para o usu�rio SYS do CDB --
--------------------------------------

-- Execute os seguintes passos:
SET SERVEROUTPUT ON

-- Inicio da coleta
exec dbms_stats.gather_system_stats('start');

-- Observe que a coleta est� acontecendo
select * from sys.aux_stats$;

-- Rotina de calibra��o
-- Este processo pode ser um pouco demorado
DECLARE
  l_latency  PLS_INTEGER;
  l_iops     PLS_INTEGER;
  l_mbps     PLS_INTEGER;
BEGIN
   DBMS_RESOURCE_MANAGER.calibrate_io (num_physical_disks => 1, 
                                       max_latency        => 20,
                                       max_iops           => l_iops,
                                       max_mbps           => l_mbps,
                                       actual_latency     => l_latency);
 
  DBMS_OUTPUT.put_line('Max IOPS = ' || l_iops);
  DBMS_OUTPUT.put_line('Max MBPS = ' || l_mbps);
  DBMS_OUTPUT.put_line('Latency  = ' || l_latency);
END;
/

-- fim da coleta
exec dbms_stats.gather_system_stats('stop');

select * from sys.aux_stats$;

--------------------------------
-- Volte para o usu�rio CURSO --
--------------------------------

/*
  Controlando as Estat�sticas
  
  A dbms_stats possui in�meras procedures para setar estat�sticas manualmente
  caso seja necess�rio. S�o a fam�lia de procedures set_*_stats. Exemplos: 
  set_table_stats, set_index_stats, etc
  
  Tamb�m � poss�vel deletar estat�sticas [j� fizemos isso em outra pr�tica] com
  as procedures delete_*_stats.
  
  Caso voc� precise impedir que novas estat�sticas substituam as atuais, pode
  ainda utilizar o procedimento lock_*_stats. O oposto � unlock_*_stats.
  
  As vezes a coleta de estat�sticas pode ter um efeito indesejado em algumas
  tabelas. Quando isto acontece, podemos recorrer ao hist�rico de estat�sticas
  e restaurar uma vers�o anterior das mesmas.
  
  Ou ainda, podemos trabalhar com estat�sticas pendentes, o que torna o ambiente
  mais previs�vel por�m vai exigir maior trabalho por parte dos DBAs para
  gerenciar manualmente coletas de estat�sticas. Veremos isso em detalhes a
  seguir.
  
  Primeiro alguns setups:
 */

-- Verifica a prefer�ncia global da dbms_stats. A prefer�ncia global vale para
-- todas as coletas. PUBLISH = TRUE significa que toda coleta entra 
-- automaticamente em produ��o. FALSE indica que toda coleta fica no status
-- pendente at� ser publicada.
select dbms_stats.get_prefs('PUBLISH') from dual;

-- Com este comando eu posso mudar individualmente a preferencia de uma tabela
exec dbms_stats.set_table_prefs('SCOTT', 'EMP', 'PUBLISH', 'false');

-- Para reverter basta mudar a propriedade de novo
exec dbms_stats.set_table_prefs('SCOTT', 'EMP', 'PUBLISH', 'true');

-- Para publicar todas as estat�sticas pendentes
exec dbms_stats.publish_pending_stats(null, null);

-- Ou publicar apenas de um objeto espec�fico
exec dbms_stats.publish_pending_stats('SCOTT','EMP');

-- Para deletar as estat�sticas pendentes:
exec dbms_stats.delete_pending_stats('SCOTT','EMP');

-- Caso precise testar os efeitos de uma coleta de estat�sticas antes de
-- public�-la, pode instruir o otimizador a fazer isso com o comando abaixo:
alter session set optimizer_use_pending_statistics=true;

-- Vamos ver como isso funciona na pr�tica. Pegaremos como exemplo a tabela
-- SH.SALES:
select channel_id, count(*) 
  from sh.sales
 group by channel_id 
 order by 2;

-- Vamos garantir que estamos usando as estat�sticas atuais
alter session set optimizer_use_pending_statistics=false;

explain plan for
select s.cust_id,s.prod_id,sum(s.amount_sold)
from sh.sales s
where channel_id=9
group by s.cust_id, s.prod_id
order by s.cust_id, s.prod_id;

-- table access full?? channel id 9 tem poucas linhas!
select * from table(dbms_xplan.display);

explain plan for
select s.cust_id,s.prod_id,sum(s.amount_sold)
from sh.sales s
where channel_id = 3
group by s.cust_id, s.prod_id
order by s.cust_id, s.prod_id;

-- table access full = ok, channel_id 3 tem muitas linhas
select * from table(dbms_xplan.display);

select table_name,
       partition_name,
       num_rows, 
       empty_blocks, 
       avg_row_len, 
       blocks, 
       last_analyzed
  from dba_tab_statistics d
 where owner='SH'
   and table_name='SALES';

-- Estat�sticas de coluna
select column_name, 
       num_distinct,
       low_value,
       high_value,
       density,
       num_nulls,
       num_buckets,
       histogram
  from dba_tab_col_statistics d
 where owner='SH'
   and table_name='SALES';

-- Consegue identificar o problema???
-------------------------------------

-- N�o � o caso, j� que estamos fazendo um full table scan, por�m existem
-- estat�sticas por parti��o, se for necess�rio:
select partition_name,
       column_name, 
       num_distinct,
       low_value,
       high_value,
       density,
       num_nulls,
       num_buckets,
       histogram
  from dba_part_col_statistics d
 where owner='SH'
   and table_name='SALES';

-- Temos uma hipotese de que uma coleta de estat�sticas resolve o problema
-- mas n�o queremos piorar ainda mais o problema, ent�o vamos testar!

-- Evita que o gather stats publique as estat�sticas imediatamente
exec dbms_stats.set_table_prefs('SH','SALES','PUBLISH','FALSE');

-- Conferindo
select dbms_stats.get_prefs('PUBLISH', 'SH', 'SALES' ) FROM DUAL;

-- Coleta de estat�sticas
exec dbms_stats.gather_table_stats('SH','SALES',method_opt => 'FOR ALL COLUMNS SIZE AUTO');

-- Esta � a data da �ltima estat�stica que foi coletada. Se nenhuma coleta foi
-- feita na VM desde o inicio do curso ela deve ser diferente do dia de hoje
-- porque a coleta que fizemos agora ainda est� pendente
select last_analyzed from dba_tables where table_name='SALES';

-- Para verificar isso:
select table_name, 
       partition_name,
       last_analyzed
  from dba_tab_pending_stats;

select table_name, 
       partition_name, 
       column_name,
       raw_to_num(low_value)  low_value,
       raw_to_num(high_value) high_value,
       density,
       num_distinct
  from dba_col_pending_stats
 where owner = 'SH'
   and table_name = 'SALES'
   and column_name = 'CHANNEL_ID';

-- Vamos ver se mudou o plano
alter session set optimizer_use_pending_statistics=TRUE;

explain plan for
select s.cust_id,s.prod_id,sum(s.amount_sold)
from sh.sales s
where channel_id=9
group by s.cust_id, s.prod_id
order by s.cust_id, s.prod_id;

select * from table(dbms_xplan.display);

explain plan for
select s.cust_id,s.prod_id,sum(s.amount_sold)
from sh.sales s
where channel_id = 3
group by s.cust_id, s.prod_id
order by s.cust_id, s.prod_id;

select * from table(dbms_xplan.display);

-- Deu certo! Vamos publicar...
exec dbms_stats.publish_pending_stats ('SH','SALES');

select count(*) from dba_tab_pending_stats;

alter session set optimizer_use_pending_statistics=FALSE;

/*
  Restaurando estat�sticas antigas
  
  Como nem sempre n�s tomamos este cuidado de validar todas as estat�sticas
  pendentes antes de publicar, outra alternativa � deixar a publica��o
  autom�tica [padr�o] e restaurar as estat�sticas quando acontece algum
  problema. Veja como:
*/ 

-- A estat�stica mais antiga dispon�vel:
select dbms_stats.get_stats_history_availability  from dual;

-- Por padr�o o per�odo de reten��o � 31 dias, mas ele pode ser configurado
select dbms_stats.get_stats_history_retention from dual;

-- Alterando para 60 dias
execute dbms_stats.alter_stats_history_retention (60);
select dbms_stats.get_stats_history_retention from dual;

-- Se voc� executou todos os passos da se��o anterior, deve ter acabado de
-- atualizar as estat�sticas desta tabela
select table_name, partition_name, stats_update_time 
  from dba_tab_stats_history 
 where table_name='SALES' 
   and owner='SH';

-- Estat�stica atual
select partition_name,
       column_name, 
       num_distinct,
       num_nulls,
       num_buckets,
       histogram
  from dba_part_col_statistics d
 where owner='SH'
   and table_name='SALES'
   and column_name = 'CHANNEL_ID';
   
select systimestamp from dual;

-- Voltando as estat�sticas para duas horas atr�s
execute dbms_stats.restore_table_stats('SH','SALES',SYSTIMESTAMP - 2/24);

-- Estat�stica restaurada
select partition_name,
       column_name, 
       num_distinct,
       num_nulls,
       num_buckets,
       histogram
  from dba_part_col_statistics d
 where owner='SH'
   and table_name='SALES'
   and column_name = 'CHANNEL_ID';

-- Voltamos ao plano anterior
explain plan for
select s.cust_id,s.prod_id,sum(s.amount_sold)
from sh.sales s
where channel_id=9
group by s.cust_id, s.prod_id
order by s.cust_id, s.prod_id;

select * from table(dbms_xplan.display);

-- Finalmente, se eu quiser comparar as estat�sticas da tabela:

select *
  from table(dbms_stats.diff_table_stats_in_history('SH',
                                                    'SALES', 
                                                    systimestamp - 1));
                                                    
-- Ou comparar estat�sticas pendentes:
exec dbms_stats.gather_table_stats('SH','SALES',method_opt => 'FOR ALL COLUMNS SIZE AUTO');

select *
  from table(dbms_stats.diff_table_stats_in_pending('SH','SALES'));

exec dbms_stats.publish_pending_stats ('SH','SALES');

select *
  from table(dbms_stats.diff_table_stats_in_history('SH',
                                                    'SALES', 
                                                    systimestamp - 1));


-- Refer�ncias:
-- http://psoug.org/reference/dbms_stats.html
-- https://oracle-base.com/articles/11g/statistics-collection-enhancements-11gr1
-- http://gavinsoorma.com/2009/09/11g-pending-and-published-statistics/
-- http://gavinsoorma.com/2011/03/restoring-optimizer-statistics/
-- https://jonathanlewis.wordpress.com/2006/11/29/low_value-high_value/