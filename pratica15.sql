/* pratica15.sql: Processamento Nativo
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
  O objetivo desta pr�tica � demonstrar os benef�cios da compila��o nativa
  e dos tipos de dados nativos
*/

-- Os scripts desta pr�tica usam dbms_output como sa�da
set serveroutput on

-- Verificar que o par�metro PLSQL_CODE_TYPE est� como INTERPRETED
show parameter plsql_code_type;

-- Voc� pode controlar o tipo de compila��o por par�metro de sistema (acima),
-- por sess�o ou por objeto. Para mudar o tipo de compila��o por sess�o, voc�
-- pode executar:

-- Para interpretado:
alter session set plsql_code_type = interpreted;

-- Para nativo:
alter session set plsql_code_type = native;

-- View que mostra propriedades do c�digo
select name, 
       type, 
       plsql_optimize_level, 
       plsql_code_type
  from user_plsql_object_settings u
 order by plsql_code_type;

-------------------------
-- CEN�RIO 1: FATORIAL --
-------------------------

-- Cria fun��o Fatorial
create or replace function fatorial(numero number)
return number
as
begin
  case when numero = 1
       then return 1;
       when numero = 0
       then return 1;
       when numero < 0
       then raise zero_divide;
       else return fatorial(numero - 1) * numero;
  end case;
end;
/

alter function fatorial compile plsql_code_type=interpreted;

-- Executa fun��o fatorial para todos os n�meros de 1 a 30000
-- Tempo Esperado : 161 segundos
-- Tempo Decorrido: ? segundos
drop table t_fatorial;
create table t_fatorial as
select rownum numero, fatorial(rownum) fat_numero 
  from dual connect by level <= 30000;
  
-- Compila a fun��o como c�digo NATIVO
alter function fatorial compile plsql_code_type=NATIVE;

-- Conferindo
select name, type, plsql_optimize_level, plsql_code_type
  from user_plsql_object_settings u
 where plsql_code_type = 'NATIVE';

-- Executa fun��o fatorial para todos os n�meros de 1 a 30000 (nativo)
-- Tempo Esperado : 97 segundos
-- Tempo Decorrido: ? segundos
drop table t_fatorial2;
create table t_fatorial2 as
select rownum numero, fatorial(rownum) fat_numero 
  from dual connect by level <= 30000;

-- Embora o c�digo nativo acima tenha benef�cios sobre o interpretado
-- ainda � gasto bastante tempo com trocas de contexto SQL <-> PLSQL
--
-- O cen�rio abaixo explora o mesmo conceito, por�m com PLSQL puro
create or replace procedure calcula_fatorial(limite number) 
as
  inicio number := dbms_utility.get_time;
  fim    number;
  
  fat    number;
begin
  for i in 1 .. limite
  loop
    fat  := fatorial(i);
  end loop;
  
  dbms_output.put_line('Tempo Decorrido: ' || 
                        to_char(dbms_utility.get_time - inicio) ||
                        ' hsecs');
end;
/

alter function  fatorial         compile plsql_code_type=interpreted;
alter procedure calcula_fatorial compile plsql_code_type=interpreted;

-- Tempo esperado:
--  10000 -  1964 hsecs
--  30000 - 15995 hsecs
--  50000 - 49023 hsecs
begin
  calcula_fatorial(30000);
end;
/

alter function  fatorial         compile plsql_code_type=native;
alter procedure calcula_fatorial compile plsql_code_type=native;

-- Tempo esperado:
--  10000 -   789 hsecs
--  30000 -  9434 hsecs
--  50000 - 27832 hsecs
begin
  calcula_fatorial(30000);
end;
/

-------------------------------
-- CEN�RIO 2: N�MEROS PRIMOS --
-------------------------------

-- Esta fun��o testa se um n�mero � primo ou n�o
create or replace function primo(numero number)
return boolean
as
  x number := 3;
begin
  case when numero = 1
       then return false;
       when numero = 2
       then return true;
       when numero < 1
       then return false;
       when mod(numero, 2) = 0
       then return false;
       else
          loop
            exit when x > trunc(sqrt(numero) + 1);
            if mod(numero, x) = 0 then 
              return false;
            end if;
            x := x + 2;
          end loop;
          return true;
  end case;
end;
/

-- Esta procedure testa todos os n�meros de 1 at� o 'limite'
-- e retorna o n�mero de primos encontrados.
create or replace procedure calcula_primos(limite number)
as
  x number := 1;
  t number := dbms_utility.get_time;
  
  num_primos number := 0;
begin
  loop
    exit when x > limite;
    if primo(x) then
      --dbms_output.put_line(x);
      num_primos := num_primos + 1;
    end if;
    x := x + 1;
  end loop;
  
  dbms_output.put_line('N�meros primos : ' || num_primos || ' n�meros primos');
  dbms_output.put_line('Tempo Decorrido: ' || 
                        to_char(dbms_utility.get_time - t) || ' hsecs');
end;
/

-- Tempo esperado: 
--  1.000.000 -  1453 hsecs
--  5.000.000 - 16110 hsecs
-- 10.000.000 - 43384 hsecs
begin
  calcula_primos(5000000);
end;
/

alter function  primo          compile plsql_code_type=native;
alter procedure calcula_primos compile plsql_code_type=native;

-- Tempo esperado: 
--  1.000.000 -  1225 hsecs
--  5.000.000 - 15076 hsecs
-- 10.000.000 - 40962 hsecs
begin
  calcula_primos(5000000);
end;
/

-- Esta procedure repete uma opera��o de soma num_loops vezes para
-- cada tipo de dado num�rico e exibe um relat�rio de tempo no final
create or replace procedure testa_numeros_inteiros(num_loops number)
as
  l_number1          NUMBER := 1;
  l_number2          NUMBER := 1;
  l_integer1         INTEGER := 1;
  l_integer2         INTEGER := 1;
  l_pls_integer1     PLS_INTEGER := 1;
  l_pls_integer2     PLS_INTEGER := 1;
  l_binary_integer1  BINARY_INTEGER := 1;
  l_binary_integer2  BINARY_INTEGER := 1;
  l_simple_integer1  BINARY_INTEGER := 1;
  l_simple_integer2  BINARY_INTEGER := 1;
  l_loops            NUMBER := num_loops;
  l_start            NUMBER;
BEGIN
  -- Time NUMBER.
  l_start := DBMS_UTILITY.get_time;
  
  FOR i IN 1 .. l_loops LOOP
    l_number1 := l_number1 + l_number2;
  END LOOP;
  
  DBMS_OUTPUT.put_line('NUMBER         : ' ||
                       (DBMS_UTILITY.get_time - l_start) || ' hsecs');

  -- Time INTEGER.
  l_start := DBMS_UTILITY.get_time;
  
  FOR i IN 1 .. l_loops LOOP
    l_integer1 := l_integer1 + l_integer2;
  END LOOP;
  
  DBMS_OUTPUT.put_line('INTEGER        : ' ||
                       (DBMS_UTILITY.get_time - l_start) || ' hsecs');

  -- Time PLS_INTEGER.
  l_start := DBMS_UTILITY.get_time;
  
  FOR i IN 1 .. l_loops LOOP
    l_pls_integer1 := l_pls_integer1 + l_pls_integer2;
  END LOOP;
  
  DBMS_OUTPUT.put_line('PLS_INTEGER    : ' ||
                       (DBMS_UTILITY.get_time - l_start) || ' hsecs');

  -- Time BINARY_INTEGER.
  l_start := DBMS_UTILITY.get_time;
  
  FOR i IN 1 .. l_loops LOOP
    l_binary_integer1 := l_binary_integer1 + l_binary_integer2;
  END LOOP;
  
  DBMS_OUTPUT.put_line('BINARY_INTEGER : ' ||
                       (DBMS_UTILITY.get_time - l_start) || ' hsecs');

  -- Time SIMPLE_INTEGER.
  l_start := DBMS_UTILITY.get_time;
  
  FOR i IN 1 .. l_loops LOOP
    l_simple_integer1 := l_simple_integer1 + l_simple_integer2;
  END LOOP;
  
  DBMS_OUTPUT.put_line('SIMPLE_INTEGER : ' ||
                       (DBMS_UTILITY.get_time - l_start) || ' hsecs');
END testa_numeros_inteiros;
/

-- Testando primeiro interpretada
alter procedure testa_numeros_inteiros compile plsql_code_type=interpreted;

-- Observe a diferen�a de tempo em cada tipo de dado
begin
  testa_numeros_inteiros(50000000);
end;
/

-- Agora como nativa
alter procedure testa_numeros_inteiros compile plsql_code_type=native;

-- Observe novamente as diferen�as de tempo
begin
  testa_numeros_inteiros(50000000);
end;
/

-- Esta procedure repete uma opera��o de soma num_loops vezes para cada tipo de
-- dado num�rico de ponto flutuante e exibe um relat�rio de tempo no final
create or replace procedure testa_numeros_ponto_flutuante(num_loops number)
as 
  l_number1         NUMBER := 1.1;
  l_number2         NUMBER := 1.1;
  l_binary_float1   BINARY_FLOAT := 1.1;
  l_binary_float2   BINARY_FLOAT := 1.1;
  l_simple_float1   SIMPLE_FLOAT := 1.1;
  l_simple_float2   SIMPLE_FLOAT := 1.1;
  l_binary_double1  BINARY_DOUBLE := 1.1;
  l_binary_double2  BINARY_DOUBLE := 1.1;
  l_simple_double1  SIMPLE_DOUBLE := 1.1;
  l_simple_double2  SIMPLE_DOUBLE := 1.1;
  l_loops           NUMBER := num_loops;
  l_start           NUMBER;
BEGIN
  -- Time NUMBER.
  l_start := DBMS_UTILITY.get_time;
  
  FOR i IN 1 .. l_loops LOOP
    l_number1 := l_number1 + l_number2;
  END LOOP;
  
  DBMS_OUTPUT.put_line('NUMBER         : ' ||
                       (DBMS_UTILITY.get_time - l_start) || ' hsecs');

  -- Time BINARY_FLOAT.
  l_start := DBMS_UTILITY.get_time;
  
  FOR i IN 1 .. l_loops LOOP
    l_binary_float1 := l_binary_float1 + l_binary_float2;
  END LOOP;
  
  DBMS_OUTPUT.put_line('BINARY_FLOAT   : ' ||
                       (DBMS_UTILITY.get_time - l_start) || ' hsecs');

  -- Time SIMPLE_FLOAT.
  l_start := DBMS_UTILITY.get_time;
  
  FOR i IN 1 .. l_loops LOOP
    l_simple_float1 := l_simple_float1 + l_simple_float2;
  END LOOP;
  
  DBMS_OUTPUT.put_line('SIMPLE_FLOAT   : ' ||
                       (DBMS_UTILITY.get_time - l_start) || ' hsecs');

  -- Time BINARY_DOUBLE.
  l_start := DBMS_UTILITY.get_time;
  
  FOR i IN 1 .. l_loops LOOP
    l_binary_double1 := l_binary_double1 + l_binary_double2;
  END LOOP;
  
  DBMS_OUTPUT.put_line('BINARY_DOUBLE  : ' ||
                       (DBMS_UTILITY.get_time - l_start) || ' hsecs');

  -- Time SIMPLE_DOUBLE.
  l_start := DBMS_UTILITY.get_time;
  
  FOR i IN 1 .. l_loops LOOP
    l_simple_double1 := l_simple_double1 + l_simple_double2;
  END LOOP;
  
  DBMS_OUTPUT.put_line('SIMPLE_DOUBLE  : ' ||
                       (DBMS_UTILITY.get_time - l_start) || ' hsecs');
END testa_numeros_ponto_flutuante;
/

-- Iniciando com compila��o interpretada
alter procedure testa_numeros_ponto_flutuante compile plsql_code_type=interpreted;

-- Repare nos tempos
begin
  testa_numeros_ponto_flutuante(50000000);
end;
/

-- Agora com compila��o nativa
alter procedure testa_numeros_ponto_flutuante compile plsql_code_type=native;

-- O que aconteceu com os tempos?
begin
  testa_numeros_ponto_flutuante(50000000);
end;
/
