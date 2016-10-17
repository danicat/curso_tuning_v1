/* pratica00.sql: Setup do Ambiente
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
  Este script cont�m o setup inicial do usu�rio do curso. Executar ele como
  usu�rio SYSTEM ou SYS no servi�o ORCL.
*/

/*
  O ambiente da pr�tica est� configurado com um Oracle Database 12c Enterprise
  Edition 12.1.0.2 com as options in-memory e multitenant.
  
  Destacando a import�ncia do multitenant, isto implica que a forma para
  realizar altera��es no banco de dados � um pouco diferente do que est�o
  acostumados com a arquitetura n�o multitenant.
  
  O banco de dados que vamos utilizar para as pr�ticas se chama ORCL. Ele
  � um PDB (pluggable database) dentro do container ORCL12C (tamb�m chamado de
  CDB).
  
  Algumas opera��es de altera��o de par�metros ser�o permitidas dentro do PDB,
  por�m outras precisaremos acessar o CDB diretamente. Instru��es apropriadas
  ser�o apresentadas quando formos alterar um ou outro.
  
  Apenas para come�armos a nos acostumar com a id�ia, abaixo apresento dois
  comandos que v�o nos ajudar a navegar entre os databases:
 */

-- mostra o id do container (pdb ou cdb) atual
show con_id
-- mostra o nome do container (pdb ou cdb) atual
show con_name

/*
  A primeira tarefa � criarmos um usu�rio "menos" privilegiado para o curso,
  pois n�o � adequado utilizar o usu�rio SYS ou SYSTEM para tarefas que n�o 
  sejam extritamente da al�ada dos mesmos.
  
  O Oracle trata os usu�rios SYS e SYSTEM com caracter�sticas especiais e podem
  existir diferen�as significativas de comportamento entre um processo que roda
  com um destes usu�rios e outro processo comum.
  
  Por este motivo vamos criar um usu�rio com privil�gios de DBA para o restante
  do curso, e usar SYS ou SYSTEM apenas quando necess�rio.
 */

-- Primeiro passo: descobrir o IP da m�quina virtual
-- Executar no SO da VM
ifconfig enp0s3

/*
  Com o IP da VM em m�os, precisamos configurar a conex�o no banco. Para 
  facilitar, voc� pode querer adicionar um alias para o IP no arquivo 'hosts'
  do seu sistema operacional. Este passo � inteiramente opcional.
 */
 
/*
  O pr�ximo passo � criar os mapeamentos de conex�o no banco de dados. Se voc�
  estiver utilizando o SQL Developer este � um processo simples. Basta adicionar
  uma nova conex�o e informar o IP ou alias e os dados abaixo.
  
  Caso voc� prefira utilizar o m�todo pelo Oracle client, dever� adicionar um
  TNSNAMES no seu tnsnames.ora.
 */

/*
  Configurar os seguintes bancos de dados/conex�es:
  
  --- SYSDBA do CDB ---
  usu�rio : sys
  password: oracle
  role    : sysdba
  hostname: ip-da-vm ou alias
  sid     : orcl12c

  --- SYSTEM do CDB ---
  usu�rio : system
  password: oracle
  role    : default
  hostname: ip-da-vm ou alias
  sid     : orcl12c
  
  --- SYSDBA do PDB ---
  usu�rio : sys
  password: oracle
  role    : sysdba
  hostname: ip-da-vm ou alias
  service : orcl
  
  --- SYSTEM do PDB ---
  usu�rio : system
  password: oracle
  role    : default
  hostname: ip-da-vm ou alias
  sid     : orcl  
*/

/*
  Conectar como usu�rio SYSTEM do PDB para criar o usu�rio para o curso,
  conforme os comandos abaixo:
 */

-- Cria usu�rio para o curso

--drop user curso;
create user curso identified by curso;
grant connect to curso;
grant dba     to curso;

-- Aumenta o espa�o em disco para o tablespace de usu�rios
alter tablespace users add datafile '/u01/app/oracle/oradata/orcl12c/orcl/users02.dbf' size 1G;

-- Ativa coleta de estat�sticas completa
show parameter statistics_level;
alter system set statistics_level=all scope=both;

/*
  O pr�ximo passo exige acessar o CDB como SYSDBA. Executar os comandos no
  sistema operacional da VM.
 */

-- Aumenta mem�ria disponivel para o banco para 1 GB
-- Executar no sistema operacional:
> sqlplus sys/oracle@//localhost:1521/orcl12c as sysdba

-- Apenas para criar o h�bito
show con_name
show con_id

-- Configura o AMM para 1G (era 800M)
alter system set memory_max_target=1G scope=spfile;
alter system set memory_target=1G scope=spfile;
shutdown immediate;
startup;

/* Pronto! o sistema est� preparado. */