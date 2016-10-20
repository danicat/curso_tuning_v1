/* pratica14.sql: Trace de Aplicações
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
  O objetivo desta prática é mostrar as ferramentas disponíveis de tracing e
  como instrumentar as aplicações para facilitar o seu diagnóstico
*/

/*
  dbms_application_info é a package que nós podemos utilizar para instrumentar
  as aplicações. Com ela podemos preencher as informações module_name,
  action_name e client_info que aparecem na v$session
  
  Além disso, estas informações podem ser utilizadas para orientar o trace.
 */
begin
  dbms_application_info.set_module(module_name => 'Controle de Estoque', 
                                   action_name => 'Executando Relatório de Materiais');
end;
/

select osuser, 
       machine,
       program,
       module,
       action 
  from v$session 
 where username = user;

begin
  dbms_application_info.set_client_info('data, hora, meu IP, etc...');
end;
/

select client_info 
  from v$session 
 where sid=(select sid from v$mystat where rownum=1);

select sys_context('USERENV', 'TERMINAL') micro,
       sys_context('USERENV', 'IP_ADDRESS') ip,
       sys_context('USERENV', 'OS_USER') usuario_rede 
  from dual;

/*
  Tkprof: esta é uma ferramenta de formatação de arquivos de trace para
  extrair os principais dados e gerar um relatório.
 */

-- Relembrando: podemos colocar um identificador no trace file com este comando:
alter session set tracefile_identifier = 'aula04';

-- Relembrando: podemos achar o trace file com essa consulta
select value
from   v$diag_info
where  name = 'Default Trace File';

-- Abaixo vamos simular uma aplicação real criando uma tabela e um
-- processo que insere linhas nesta tabela.
create table sql_trace_test (
  id  number,
  description  varchar2(50)
);

exec dbms_stats.gather_table_stats(user, 'sql_trace_test');

create or replace procedure populate_sql_trace_test (p_loops  in  number) as
  l_number  number;
begin
  for i in 1 .. p_loops loop
    insert into sql_trace_test (id, description)
    values (i, 'Description for ' || i);
  end loop;
  
  select count(*)
  into   l_number
  from   sql_trace_test;
  
  commit;
  
  dbms_output.put_line(l_number || ' rows inserted.');
end;
/
show errors

alter session set events '10046 trace name context forever, level 8';

set serveroutput on
exec populate_sql_trace_test(p_loops => 10);

alter session set events '10046 trace name context off';

-- Vá na linha de comando do servidor e acesse o diretório onde está o arquivo
-- de trace. 
-- Execute o comando abaixo na linha de comando para gerar o arquivo de texto
> tkprof <nome-do-arquivo>.trc trace_aula4.txt sys=no waits=yes explain=curso/curso@orcl


/*
  dbms_monitor
 */

-- TRACE por serviço, modulo e ação

-- Verifica o nome da instância para passar por parâmetro (pode ser omitido
-- para ativar na instancia atual - útil para RAC)
select instance_name from gv$instance;

-- Ativa o trace por serviço, modulo e ação
begin
  dbms_monitor.serv_mod_act_trace_enable(service_name  => 'ORCL', 
                                         module_name   => dbms_monitor.all_modules, 
                                         action_name   => dbms_monitor.all_actions, 
                                         waits         => TRUE, 
                                         binds         => TRUE, 
                                         instance_name =>'orcl12c');
end;
/

-- Desativa o trace por serviço, modulo e ação
-- Ativa o trace por serviço, modulo e ação
begin
  dbms_monitor.serv_mod_act_trace_disable(service_name  => 'ORCL', 
                                          module_name   => dbms_monitor.all_modules, 
                                          action_name   => dbms_monitor.all_actions, 
                                          instance_name =>'orcl12c');
end;
/

-- TRACE por sessão
select sid, serial#
  from v$session 
 where username = user;

-- Ativa o trace para uma sessão pelo sid,serial#
begin
  dbms_monitor.session_trace_enable(session_id => 292, 
                                    serial_num => 59176, 
                                    waits      => TRUE, 
                                    binds      => FALSE);
end;
/

-- Se você não informar parâmetros ele faz o trace da sessão atual:
exec dbms_monitor.session_trace_enable;
-- ou
exec dbms_monitor.session_trace_enable(NULL, NULL);
-- ou ainda, especificando parâmetros:
exec dbms_monitor.session_trace_enable(NULL, NULL, TRUE, TRUE);
exec dbms_monitor.session_trace_enable(binds=>TRUE);

-- Desativa o trace por sessão
begin
  dbms_monitor.session_trace_enable(session_id => 292, 
                                    serial_num => 59176);
end;
/

-- http://psoug.org/reference/dbms_monitor.html
-- http://eduardolegatti.blogspot.com/2009/05/um-pouco-do-pacote-dbmsapplicationinfo.html#ixzz4Ne2RVq1V 
-- https://oracle-base.com/articles/misc/sql-trace-10046-trcsess-and-tkprof#tracing_individual_sql_statements