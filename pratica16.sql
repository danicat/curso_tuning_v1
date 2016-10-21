/* pratica16.sql: Bulk Collect e Forall
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
  O objetivo desta prática é demonstrar as técnicas de processamento em
  massa BULK COLLECT e FORALL.
*/

/*
  Nós vamos criar uma massa de dados para simular um processo de aumento
  de salário na tabela de funcionários. A regra é dar um aumento de acordo
  com a Avaliação de Desempenho (coluna aval).
  
  Note que a regra poderia ser facilmente implementada em um único update,
  porém o objetivo aqui é demonstrar a técnica para ser aplicada em cenários
  mais complexos.
 */

set serveroutput on

-- Cria uma massa de dados para o nosso processo
drop table employees;
create table employees as
select * from hr.employees, (select rownum from dual connect by level <= 5000);

create index emp_idx on employees(employee_id);

-- ~500k linhas
select count(*) from employees;

-- Adiciona a coluna avaliação  
alter table employees add aval number;

-- Seta o seed para garantir reproducibilidade
begin
  dbms_random.seed(1234);
end;
/

-- Atribui uma avaliação de desempenho aleatória para cada funcionário
-- Garante que cada funcionário tem um id unico
update employees
   set aval        = trunc(dbms_random.value(1,5)),
       employee_id = rownum;
   
commit;

-- Verificando
select employee_id, count(*)
  from employees
 group by employee_id
 having count(*) > 1;

begin
  dbms_stats.gather_table_stats(user, 'EMPLOYEES');
end;
/

select employee_id, salary, aval
  from employees
fetch first 5 rows only;
  
-- Nossa procedure de negócio
-- Versão 1: lenta, faz um loop e update linha a linha
create or replace procedure aumenta_salario
as
  v_salario_novo  employees.salary%TYPE;
  t0              number := dbms_utility.get_time;
begin
  for emp in (select employee_id, salary, aval from employees)
  loop
    v_salario_novo := emp.salary * case when emp.aval = 5
                                        then 1.5
                                        when emp.aval = 4
                                        then 1.3
                                        when emp.aval = 3
                                        then 1.2
                                        when emp.aval = 2
                                        then 1.1
                                        else 1.0
                                    end;
    update employees
       set salary      = v_salario_novo
     where employee_id = emp.employee_id; 
  end loop;
  
  dbms_output.put_line('Tempo decorrido: ' || 
                       to_char(dbms_utility.get_time - t0) || ' hsecs');
end;
/

-- Executa o processo
-- Tempo Decorrido: ? [Estimado 24 s]
begin
  aumenta_salario;
end;
/
commit;

-- Versão 2: um pouco melhor, utilizamos o bulk collect para ler várias linhas
--           em cada passada. Note que o default do FOR é ler de 100 em 100,
--           por isso vamos chamar a função com o parâmetro 1000, o que vai
--           causar uma redução de 10x no número de fetches.
create or replace procedure aumenta_salario(num_linhas in pls_integer default 100)
as
  cursor c_emp is
  select employee_id, salary, aval from employees;
  
  type emp_arr_typ is table of c_emp%rowtype index by pls_integer;
  a_emp emp_arr_typ ;

  t0              number := dbms_utility.get_time;
begin
  open c_emp;
  loop
    fetch c_emp BULK COLLECT into a_emp limit num_linhas;
    
    for i in 1 .. a_emp.count
    loop
      a_emp(i).salary := a_emp(i).salary * case when a_emp(i).aval = 5
                                                then 1.5
                                                when a_emp(i).aval = 4
                                                then 1.3
                                                when a_emp(i).aval = 3
                                                then 1.2
                                                when a_emp(i).aval = 2
                                                then 1.1
                                                else 1.0
                                           end;
      update employees
         set salary      = a_emp(i).salary
       where employee_id = a_emp(i).employee_id; 
    end loop;
    
    exit when a_emp.count < num_linhas;
    
  end loop;

  dbms_output.put_line('Tempo decorrido: ' || 
                       to_char(dbms_utility.get_time - t0) || ' hsecs');
end;
/

-- Execute e marque o tempo
-- Tempo Decorrido: ? [Estimado: 22 s]
begin
  aumenta_salario(1000);
end;
/
commit;

-- Versão 3: Rápida, além do fetch de 1000 em 1000, melhoramos o código fazendo
--           o update de 1000 em 1000. Este é o melhor dos mundos se tratando
--           de processamento com PL/SQL.
create or replace procedure aumenta_salario(num_linhas in pls_integer default 100)
as
  cursor c_emp is
  select employee_id, salary, aval from employees;
  
  type emp_arr_typ is table of c_emp%rowtype index by pls_integer;
  a_emp emp_arr_typ ;

  t0              number := dbms_utility.get_time;
begin
  open c_emp;
  loop
    fetch c_emp bulk collect into a_emp limit num_linhas;
    
    for i in 1 .. a_emp.count
    loop
      a_emp(i).salary := a_emp(i).salary * case when a_emp(i).aval = 5
                                                then 1.5
                                                when a_emp(i).aval = 4
                                                then 1.3
                                                when a_emp(i).aval = 3
                                                then 1.2
                                                when a_emp(i).aval = 2
                                                then 1.1
                                                else 1.0
                                           end;
    end loop;
    
    forall i in 1 .. a_emp.count
    update employees
       set salary      = a_emp(i).salary
     where employee_id = a_emp(i).employee_id;
    
    exit when a_emp.count < num_linhas;
    
  end loop;

  dbms_output.put_line('Tempo decorrido: ' || 
                       to_char(dbms_utility.get_time - t0) || ' hsecs');
end;
/

-- Execute e marque o tempo
-- Tempo Decorrido: ? [Estimado: 9 s]
begin
  aumenta_salario(1000);
end;
/
commit;

-- Versão 4: Mais rápida
create or replace procedure aumenta_salario(num_linhas in pls_integer default 100)
as
  cursor c_emp is
  select employee_id, salary, aval, rowid from employees;
  
  type emp_arr_typ is table of c_emp%rowtype index by pls_integer;
  a_emp emp_arr_typ ;

  t0              number := dbms_utility.get_time;
begin
  open c_emp;
  loop
    fetch c_emp bulk collect into a_emp limit num_linhas;
    
    for i in 1 .. a_emp.count
    loop
      a_emp(i).salary := a_emp(i).salary * case when a_emp(i).aval = 5
                                                then 1.5
                                                when a_emp(i).aval = 4
                                                then 1.3
                                                when a_emp(i).aval = 3
                                                then 1.2
                                                when a_emp(i).aval = 2
                                                then 1.1
                                                else 1.0
                                           end;
    end loop;
    
    forall i in 1 .. a_emp.count
    update employees
       set salary    = a_emp(i).salary
     where rowid     = a_emp(i).rowid;
    
    exit when a_emp.count < num_linhas;
    
  end loop;

  dbms_output.put_line('Tempo decorrido: ' || 
                       to_char(dbms_utility.get_time - t0) || ' hsecs');
end;
/

-- Execute e marque o tempo
-- Tempo Decorrido: ? [Estimado: 7 s]
begin
  aumenta_salario(1000);
end;
/
commit;

-- Do jeito correto
-- Tempo Decorrido: ? [Estimado: 4 s]
update (select employee_id, 
               salary, 
               case when aval = 5
                    then 1.5
                    when aval = 4
                    then 1.3
                    when aval = 3
                    then 1.2
                    when aval = 2
                    then 1.1
                    else 1.0
                end fator
          from employees)
   set salary = salary * fator;

commit;


-----------------------
-- FORALL INDICES OF --
-----------------------

/*
  Um novo requisito surgiu! A diretoria decidiu que a TI já ganha bem demais
  e não precisa de aumento. O departamento da TI é o id 10.
 */
 
select department_id, count(*)
  from employees
 group by department_id
 order by 1;

-- Mesma função, com a regra nova
create or replace procedure aumenta_salario_exceto_ti(num_linhas in pls_integer default 100)
as
  cursor c_emp is
  select employee_id, department_id, salary, aval, rowid from employees;
  
  type emp_arr_typ is table of c_emp%rowtype index by pls_integer;
  a_emp emp_arr_typ ;

  t0              number := dbms_utility.get_time;
begin
  open c_emp;
  loop
    fetch c_emp bulk collect into a_emp limit num_linhas;
    
    for i in 1 .. a_emp.count
    loop
      if a_emp(i).department_id != 10 then
        a_emp(i).salary := a_emp(i).salary * case when a_emp(i).aval = 5
                                                  then 1.5
                                                  when a_emp(i).aval = 4
                                                  then 1.3
                                                  when a_emp(i).aval = 3
                                                  then 1.2
                                                  when a_emp(i).aval = 2
                                                  then 1.1
                                                  else 1.0
                                             end;
      else
        -- TI não precisa de mais dinheiro
        -- remove da coleção
        a_emp.delete(i);
      end if;
    end loop;

    forall i in INDICES OF a_emp
    update employees
       set salary    = a_emp(i).salary
     where rowid     = a_emp(i).rowid;
    
    exit when a_emp.count < num_linhas;
    
  end loop;

  dbms_output.put_line('Tempo decorrido: ' || 
                       to_char(dbms_utility.get_time - t0) || ' hsecs');
end;
/

-- Antes
select employee_id, salary, aval, department_id
  from employees
 where department_id in (10,20)
   and aval > 1
fetch first 10 rows only;

-- Execute
begin
  aumenta_salario_exceto_ti(1000);
end;
/
commit;

-- Depois
select employee_id, salary, aval, department_id
  from employees
 where department_id in (10,20)
   and aval > 1
fetch first 10 rows only;

----------------------------
-- FORALL SAVE EXCEPTIONS --
----------------------------

/*
  Mais um dia de trabalho começa e mais uma regra surgiu: agora nenhum
  funcionário pode ganhar mais do que 100 mil de salário.
 */

-- Provavelmente ilegal...
update employees
   set salary = 100000
 where salary > 100000;

commit;

-- Deixa a diretoria tranquila de novo
alter table employees add constraint salario_100k CHECK (salary <= 100000);

-- Precisamos capturar as exceções caso o processo aumente o salário além de 100k
create or replace procedure aumenta_salario_exceto_ti(num_linhas in pls_integer default 100)
as
  cursor c_emp is
  select employee_id, department_id, salary, aval, rowid from employees;
  
  type emp_arr_typ is table of c_emp%rowtype index by pls_integer;
  a_emp emp_arr_typ ;

  t0              number := dbms_utility.get_time;
begin
  open c_emp;
  loop
    fetch c_emp bulk collect into a_emp limit num_linhas;
    
    for i in 1 .. a_emp.count
    loop
      if a_emp(i).department_id != 10 then
        a_emp(i).salary := a_emp(i).salary * case when a_emp(i).aval = 5
                                                  then 1.5
                                                  when a_emp(i).aval = 4
                                                  then 1.3
                                                  when a_emp(i).aval = 3
                                                  then 1.2
                                                  when a_emp(i).aval = 2
                                                  then 1.1
                                                  else 1.0
                                             end;
      else
        -- TI não precisa de mais dinheiro
        -- remove da coleção
        a_emp.delete(i);
      end if;
    end loop;

    -- captura exceções da constraint caso alguém tenha o salário atualizado
    -- para mais de 100k e não perde o processamento
    begin 
      forall i in INDICES OF a_emp SAVE EXCEPTIONS
      update employees
         set salary    = a_emp(i).salary
       where rowid     = a_emp(i).rowid;
    exception
      when others then
        if sqlcode = -24381 -- exceção do Forall
        then
          for i in 1 .. sql%bulk_exceptions.count
          loop
            dbms_output.put_line(sql%bulk_exceptions(i).error_index || ': '
                              || sql%bulk_exceptions(i).error_code);
         end loop;
      else
         raise;
      end if;
    end;
    
    exit when a_emp.count < num_linhas;
    
  end loop;

  dbms_output.put_line('Tempo decorrido: ' || 
                       to_char(dbms_utility.get_time - t0) || ' hsecs');
end;
/

-- Execute e observe... violação de check constraint é o ORA-02290
begin
  aumenta_salario_exceto_ti(1000);
end;
/
commit;
