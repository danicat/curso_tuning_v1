/* pratica05.sql: Padr�es de Codifica��o
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
  Nesta aula vamos explorar o impacto de padr�es de codifica��o no banco de
  dados.
*/

/*
  N�s vamos utilizar as estat�sticas de sess�o para entender o que est�
  acontecendo por debaixo dos panos. Relembrando, a v$mystat � a view que 
  mostra apenas estat�sticas do usu�rio atual.
 */

desc v$mystat;

select *
  from v$mystat;
 
/*
  E a v$statname descreve cada uma das estat�sticas.
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
  Nesta aula, estamos interessados nas estat�sticas de hard parse.
*/

select vs.statistic#, display_name, value
  from v$mystat   vm,
       v$statname vs
 where vm.statistic# = vs.statistic#
   and display_name like 'parse%';
   
-- Este comando limpa todos os cursores da shared pool
alter system flush shared_pool;
-- a partir de agora todas as primeiras execu��es de querys s�o hard parse!
   
-- execute as querys abaixo, por�m entre cada uma delas observe o n�mero
-- de hard parses reexecutando a query acima

select * from dual;
select *  from dual;
select  * from dual;

-- Fa�a experimentos com o n�mero de espa�os, capitaliza��o e etc
-- voc� ver� que sempre que o cursor gerar um texto novo ele ativa um hard
-- parse.