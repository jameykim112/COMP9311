-- COMP9311 17s1 Project 1
--
-- MyMyUNSW Solution Template


-- Q1: buildings that have more than 30 rooms
create or replace view distinct_rooms(unswid, name)
AS
select distinct on (rooms.unswid) buildings.unswid, buildings.name
FROM rooms
INNER JOIN buildings ON buildings.id = rooms.building
;

--... SQL statements, possibly using other views/functions defined by you ...
create or replace view distinct_rooms_count(unswid, name, count)
AS
SELECT unswid, name, count(*) from distinct_rooms
GROUP BY unswid, name
HAVING count(*) > 30;

create or replace view q1(unswid, name)
AS
SELECT unswid, name
FROM distinct_rooms
;


-- Q2: get details of the current Deans of Faculty

create or replace view current_deans(unswid)
as
select staff
from affiliations
where role = '1286' and ending IS NULL
GROUP BY staff;


create or replace view current_deans_name(unswid, name, longname)
as
select current_deans.unswid, people.name
from people
inner join current_deans on people.id = current_deans.unswid
group by current_deans.unswid, people.name
;

create or replace view Q2(name, faculty, phone, starting)
as
select current_deans_name.name, orgunits.longname, staff.phone, affiliations.starting
from affiliations
inner join current_deans_name on current_deans_name.unswid = affiliations.staff
inner join orgunits on orgunits.id = affiliations.orgunit
inner join staff on staff.id = affiliations.staff
where role = '1286' and orgunits.longname not like '%Committee' and orgunits.longname not like '%Administration'
group by current_deans_name.name, orgunits.longname, staff.phone, affiliations.starting

--... SQL statements, possibly using other views/functions defined by you ...

-- select all affiliations where role is the dean
;



-- Q3: get details of the longest-serving and shortest-serving current Deans of Faculty
create or replace view maxmin_date(name, faculty, starting)
AS
SELECT name, faculty, starting
FROM q2
WHERE starting = (select max(starting) from q2)
OR starting = (select min(starting) from q2)
;

create or replace view maxmin_date_status(name, faculty, starting)
AS
SELECT name, faculty, starting,
CASE WHEN starting = (select min(starting) from maxmin_date) THEN 'Longeset serving'
WHEN starting = (select max(starting) from maxmin_date) THEN 'Shortest serving'
END AS "status" from maxmin_date

create or replace view Q3(name, faculty, starting)
AS
SELECT status, name, faculty, starting
FROM
maxmin_date_status
;

--... SQL statements, possibly using other views/functions defined by you ...
;



-- Q4 UOC/ETFS ratio
create or replace view uoc_ratio_check(uoc, eftsload)
AS
select uoc, eftsload,
case when uoc + eftsload = 0 then 0 else uoc / eftsload
end as ratio from subjects
where ratio not null and not 0
;

create or replace view uoc_ratio_round
AS
SELECT uoc, eftsload, round(ratio::numeric,1)
FROM
uoc_ratio_check
;

create or replace view Q4(ratio,nsubjects)
as
SELECT ratio, count(*)
FROM uoc_ratio_round
WHERE ratio is not null and ratio > 0
group by ratio
;
--... SQL statements, possibly using other views/functions defined by you ...
;



-- Q5: program enrolment information from 10s1
create or replace view international_students_10S1
as
select students.id, students.stype, program_enrolments.semester, stream_enrolments.stream,
semesters.year, semesters.term, streams.code
from students
inner join program_enrolments on program_enrolments.student = students.id
inner join semesters on program_enrolments.semester = semesters.id
inner join stream_enrolments on stream_enrolments.partof = program_enrolments.id
inner join streams on streams.id = stream_enrolments.stream
where students.stype = 'intl' and
semesters.year = '2010' and
semesters.term = 'S1' and
streams.code = 'SENGA1'
;

create or replace view Q5a(num)
as
select count(*)
from international_students_10S1
;
-- Q5b

create or replace view domestic_students
as
select distinct on (students.id) students.stype, program_enrolments.semester, stream_enrolments.stream,
semesters.year, semesters.term, streams.code, programs.code
from students
inner join program_enrolments on program_enrolments.student = students.id
inner join semesters on program_enrolments.semester = semesters.id
inner join stream_enrolments on stream_enrolments.partof = program_enrolments.id
inner join streams on streams.id = stream_enrolments.stream
inner join program_degrees on program_degrees.program = program_enrolments.program
inner join programs on programs.id = program_enrolments.program
where students.stype = 'local' and
semesters.year = '2010' and
semesters.term = 'S1' and
programs.code = '3978'

create or replace view Q5b(num)
as
select count(*)
from domestic_students
--... SQL statements, possibly using other views/functions defined by you ...
;

create or replace view faculty_engineering_10s1
as
select distinct on (students.id) students.stype, program_enrolments.semester,
semesters.year, semesters.term, orgunits.id
from students
inner join program_enrolments on program_enrolments.student = students.id
inner join semesters on program_enrolments.semester = semesters.id
inner join programs on programs.id = program_enrolments.program
inner join orgunits on programs.offeredby = orgunits.id
where semesters.year = '2010' and
semesters.term = 'S1' and
orgunits.id = '112'
;

create or replace view Q5c(num)
as
select count(*)
from faculty_engineering_10s1
;
--... SQL statements, possibly using other views/functions defined by you ...


-- Q6: course CodeName


create or replace function Q6(text) returns text
	as $$
	select code||' '||name
	from subjects
	where subjects.code = $1
$$ language sql
;

-- Q7: Percentage of growth of students enrolled in Database Systems
create or replace view database_systems_enrolment
as
select semesters.year, semesters.term, semesters.starting, count(*)
from subjects
inner join courses on courses.subject = subjects.id
inner join course_enrolments on course_enrolments.course = courses.id
inner join semesters on semesters.id = courses.semester
where subjects.name = 'Database Systems'
group by semesters.year, semesters.term, semesters.starting
order by semesters.year
;

create or replace view Q7(year, term, perc_growth)
as
--... SQL statements, possibly using other views/functions defined by you ...
select t2.year, t2.term, round((cast(t2.count as float) / t1.count)::numeric,2)
from database_systems_enrolment t1, database_systems_enrolment t2
where t1.starting =
(select max(database_systems_enrolment.starting) from database_systems_enrolment where t2.starting > database_systems_enrolment.starting)
;

-- Q8: Least popular subjects

-- TABLE 1: Subjects with less than 20 students
create or replace view enrollment
as
select courses.id, count(distinct course_enrolments.student)
from course_enrolments
inner join courses on courses.id = course_enrolments.course
group by courses.id
having count(distinct course_enrolments.student) < 20
;

--Subjects >= 20

select subjects
from courses
inner join subjects on subjects.id = courses.subject
inner join semesters on semesters.id = courses.semester




create or replace view courses_semester(courses_id,subjects_id, semester_ending)
as
select courses.id, semesters.ending, subjects.id
from courses
inner join subjects on subjects.id = courses.subject
inner join semesters on semesters.id = courses.semester
order b


create or replace view courses_top20()
as
SELECT courses_id,subjects_id, semester_ending
FROM
  ( SELECT courses_id,subjects_id, semester_ending,
           ROW_NUMBER() OVER (PARTITION BY subjects_id
                              ORDER BY max(ending) DESC
                             ) AS rn
    FROM courses_semester
    GROUP BY courses_id,subjects_id, semester_ending
  ) AS t

WHERE rn <= 20
group by courses_id,subjects_id, semester_ending
ORDER BY subjects_id asc






create or replace view courses_20(id, code, name, count)
as
select subjects.id, count(courses.id)
from subjects
inner join courses on courses.subject = subjects.id
group by subjects.id, subjects.code, subjects.name

;

create or replace view courses_20_semester(id, code, name, ending)
as
select courses_20.id, courses_20.code, courses_20.name, semester.ending
from courses_20
inner join courses on courses.subject = courses_20.id
inner join semesters on semesters.id = courses.semester
order by courses_20.code


create or replace view courses_top20(subject_id, subject_code, subject_name, ending)
as
SELECT id, code, name, ending
FROM
  ( SELECT id, code, name, ending,
           ROW_NUMBER() OVER (PARTITION BY code
                              ORDER BY max(ending) DESC
                             ) AS rn
    FROM courses_20_semester
    GROUP BY id, code, name, ending
  ) AS t

WHERE rn <= 20
group by id, code, name, ending
ORDER BY code asc
;

create or replace view subject_less_20
as
select subject, subjects.code, subjects.name
from enrollment
inner join subjects on subjects.id = enrollment.subject
order by code
;

create or replace view courses_more_20
as
select subject_id, subject_code, subject_name
from courses_top20
order by subject_code
;








create or replace view Q8(subject)
as
--... SQL statements, possibly using other views/functions defined by you ...
;

create or replace view database_s1_total(year, term, starting, total)
as
select semesters.year, semesters.term, semesters.starting, count(*)
from subjects
inner join courses on courses.subject = subjects.id
inner join course_enrolments on course_enrolments.course = courses.id
inner join semesters on semesters.id = courses.semester
where subjects.name = 'Database Systems' and semesters.term = 'S1'
group by semesters.year, semesters.term, semesters.starting, course_enrolments.mark >= 0
having course_enrolments.mark >= 0
order by semesters.year
;

create or replace view database_s1_pass(year, term, starting, pass)
as
select semesters.year, semesters.term, semesters.starting, count(*)
from subjects
inner join courses on courses.subject = subjects.id
inner join course_enrolments on course_enrolments.course = courses.id
inner join semesters on semesters.id = courses.semester
where subjects.name = 'Database Systems' and semesters.term = 'S1'
group by semesters.year, semesters.term, semesters.starting, course_enrolments.mark >= 50
having course_enrolments.mark >= 50
order by semesters.year
;

create or replace view database_s1_passrate(year, term, pass, total, pass_rate)
as
select database_s1_pass.year, database_s1_pass.term, database_s1_pass.pass, database_s1_total.total,
(cast(database_s1_pass.pass as float) / cast(database_s1_total.total as float))::numeric(4,2)
from database_s1_pass
inner join database_s1_total on database_s1_total.year = database_s1_pass.year
;

create or replace view database_s2_total(year, term, starting, total)
as
select semesters.year, semesters.term, semesters.starting, count(*)
from subjects
inner join courses on courses.subject = subjects.id
inner join course_enrolments on course_enrolments.course = courses.id
inner join semesters on semesters.id = courses.semester
where subjects.name = 'Database Systems' and semesters.term = 'S2'
group by semesters.year, semesters.term, semesters.starting, course_enrolments.mark >= 0
having course_enrolments.mark >= 0
order by semesters.year
;

create or replace view database_s2_pass(year, term, starting, pass)
as
select semesters.year, semesters.term, semesters.starting, count(*)
from subjects
inner join courses on courses.subject = subjects.id
inner join course_enrolments on course_enrolments.course = courses.id
inner join semesters on semesters.id = courses.semester
where subjects.name = 'Database Systems' and semesters.term = 'S2'
group by semesters.year, semesters.term, semesters.starting, course_enrolments.mark >= 50
having course_enrolments.mark >= 50
order by semesters.year
;

create or replace view database_s2_passrate(year, term, pass, total, pass_rate)
as
select database_s2_pass.year, database_s2_pass.term, database_s2_pass.pass, database_s2_total.total,
(cast(database_s2_pass.pass as float) / cast(database_s2_total.total as float))::numeric(4,2)
from database_s2_pass
inner join database_s2_total on database_s2_total.year = database_s2_pass.year
;


-- Q9: Database Systems pass rate for both semester in each year
create or replace view Q9(year, s1_pass_rate, s2_pass_rate)
as
--... SQL statements, possibly using other views/functions defined by you ...
SELECT right(cast(database_s1_passrate.year as varchar), 2), database_s1_passrate.pass_rate, database_s2_passrate.pass_rate
from database_s1_passrate
inner join database_s2_passrate on database_s2_passrate.year = database_s1_passrate.year
order by database_s2_passrate.year
;



-- Q10: find all students who failed all black series subjects
create or replace view Q10(zid, name)
as
--... SQL statements, possibly using other views/functions defined by you ...
;
