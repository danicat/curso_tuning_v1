/* pratica05.sql: Padrões de Codificação
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
  Nesta aula vamos explorar o impacto de padrões de codificação no banco de
  dados.
*/

/*
  Nós vamos utilizar as estatísticas de sessão para entender o que está
  acontecendo por debaixo dos panos. Relembrando, a v$mystat é a view que 
  mostra apenas estatísticas do usuário atual.
 */

desc v$mystat;

select *
  from v$mystat;
 
/*
  E a v$statname descreve cada uma das estatísticas.
 */

desc v$statname
  
select *
  from v$statname;

select vs.statistic#, display_name, value
  from v$mystat   vm,
       v$statname vs
 where vm.statistic# = vs.statistic#
   and vm.value != 0;

/*
  Nesta aula, estamos interessados nas estatísticas de hard parse.
*/

select vs.statistic#, display_name, value
  from v$mystat   vm,
       v$statname vs
 where vm.statistic# = vs.statistic#
   and display_name like 'parse%';
   
-- Este comando limpa todos os cursores da shared pool
alter system flush shared_pool;
-- a partir de agora todas as primeiras execuções de querys são hard parse!
   
-- execute as querys abaixo, porém entre cada uma delas observe o número
-- de hard parses reexecutando a query acima

select * from dual;
select *  from dual;
select  * from dual;

-- Faça experimentos com o número de espaços, capitalização e etc
-- você verá que sempre que o cursor gerar um texto novo ele ativa um hard
-- parse.