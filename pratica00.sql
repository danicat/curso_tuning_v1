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
  Este script contém o setup inicial do usuário do curso. Executar ele como
  usuário SYSTEM ou SYS no serviço ORCL.
*/

/*
  O ambiente da prática está configurado com um Oracle Database 12c Enterprise
  Edition 12.1.0.2 com as options in-memory e multitenant.
  
  Destacando a importância do multitenant, isto implica que a forma para
  realizar alterações no banco de dados é um pouco diferente do que estão
  acostumados com a arquitetura não multitenant.
  
  O banco de dados que vamos utilizar para as práticas se chama ORCL. Ele
  é um PDB (pluggable database) dentro do container ORCL12C (também chamado de
  CDB).
  
  Algumas operações de alteração de parâmetros serão permitidas dentro do PDB,
  porém outras precisaremos acessar o CDB diretamente. Instruções apropriadas
  serão apresentadas quando formos alterar um ou outro.
  
  Apenas para começarmos a nos acostumar com a idéia, abaixo apresento dois
  comandos que vão nos ajudar a navegar entre os databases:
 */

-- mostra o id do container (pdb ou cdb) atual
show con_id
-- mostra o nome do container (pdb ou cdb) atual
show con_name

/*
  A primeira tarefa é criarmos um usuário "menos" privilegiado para o curso,
  pois não é adequado utilizar o usuário SYS ou SYSTEM para tarefas que não 
  sejam extritamente da alçada dos mesmos.
  
  O Oracle trata os usuários SYS e SYSTEM com características especiais e podem
  existir diferenças significativas de comportamento entre um processo que roda
  com um destes usuários e outro processo comum.
  
  Por este motivo vamos criar um usuário com privilégios de DBA para o restante
  do curso, e usar SYS ou SYSTEM apenas quando necessário.
 */

-- Primeiro passo: descobrir o IP da máquina virtual
-- Executar no SO da VM
ifconfig enp0s3

/*
  Com o IP da VM em mãos, precisamos configurar a conexão no banco. Para 
  facilitar, você pode querer adicionar um alias para o IP no arquivo 'hosts'
  do seu sistema operacional. Este passo é inteiramente opcional.
 */
 
/*
  O próximo passo é criar os mapeamentos de conexão no banco de dados. Se você
  estiver utilizando o SQL Developer este é um processo simples. Basta adicionar
  uma nova conexão e informar o IP ou alias e os dados abaixo.
  
  Caso você prefira utilizar o método pelo Oracle client, deverá adicionar um
  TNSNAMES no seu tnsnames.ora.
 */

/*
  Configurar os seguintes bancos de dados/conexões:
  
  --- SYSDBA do CDB ---
  usuário : sys
  password: oracle
  role    : sysdba
  hostname: ip-da-vm ou alias
  sid     : orcl12c

  --- SYSTEM do CDB ---
  usuário : system
  password: oracle
  role    : default
  hostname: ip-da-vm ou alias
  sid     : orcl12c
  
  --- SYSDBA do PDB ---
  usuário : sys
  password: oracle
  role    : sysdba
  hostname: ip-da-vm ou alias
  service : orcl
  
  --- SYSTEM do PDB ---
  usuário : system
  password: oracle
  role    : default
  hostname: ip-da-vm ou alias
  sid     : orcl  
*/

/*
  Conectar como usuário SYSTEM do PDB para criar o usuário para o curso,
  conforme os comandos abaixo:
 */

-- Cria usuário para o curso

--drop user curso;
create user curso identified by curso;
grant connect to curso;
grant dba     to curso;

-- Aumenta o espaço em disco para o tablespace de usuários
alter tablespace users add datafile '/u01/app/oracle/oradata/orcl12c/orcl/users02.dbf' size 1G;

-- Ativa coleta de estatísticas completa
show parameter statistics_level;
alter system set statistics_level=all scope=both;

/*
  O próximo passo exige acessar o CDB como SYSDBA. Executar os comandos no
  sistema operacional da VM.
 */

-- Aumenta memória disponivel para o banco para 1 GB
-- Executar no sistema operacional:
> sqlplus sys/oracle@//localhost:1521/orcl12c as sysdba

-- Apenas para criar o hábito
show con_name
show con_id

-- Configura o AMM para 1G (era 800M)
alter system set memory_max_target=1G scope=spfile;
alter system set memory_target=1G scope=spfile;
shutdown immediate;
startup;

/* Pronto! o sistema está preparado. */