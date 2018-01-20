-- COMP9311 17s1 Project 2
--
-- Section 1 Template

--Q1: ...
create type IncorrectRecord as (pattern_number integer, uoc_number integer);

create or replace function Q1(pattern text, uoc_threshold integer) 
	returns IncorrectRecord
as $$
--... SQL statements, possibly using other views/functions defined by you ...
$$ language plpgsql;


-- Q2: ...
create type TranscriptRecord as (cid integer, term char(4), code char(8), name text, uoc integer, mark integer, grade char(2), rank integer, totalEnrols integer);

create or replace function Q2(stu_unswid integer)
	returns setof TranscriptRecord
as $$
--... SQL statements, possibly using other views/functions defined by you ...
$$ language plpgsql;


-- Q3: ...
create type TeachingRecord as (unswid integer, staff_name text, teaching_records text);

create or replace function Q3(org_id integer, num_sub integer, num_times integer) 
	returns setof TeachingRecord 
as $$
--... SQL statements, possibly using other views/functions defined by you ...
$$ language plpgsql;



