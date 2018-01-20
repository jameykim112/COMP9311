-- COMP9311 17s1 Project 2
--
-- Section 1 Template

--Q1: ...

create or replace view records(code, eftsload, uoc, uoc_test)
as
SELECT code, eftsload, uoc, uoc/48::float
FROM subjects
;

create type IncorrectRecord as (pattern_number integer, uoc_number integer);

create or replace function Q1(pattern text, uoc_threshold integer)
	returns IncorrectRecord
as $$
declare
	irecord incorrectrecord;
begin
	SELECT count(code)::int
	INTO irecord.pattern_number -- Return value into column pattern_number in type IncorrectRecord
	FROM records
	WHERE records.code like pattern
	AND records.eftsload != records.uoc_test;
	SELECT count(code)::int
	INTO irecord.uoc_number -- Return value into column uoc_number in type IncorrectRecord
	FROM records
	WHERE records.code like pattern
	AND records.eftsload != records.uoc_test
	AND uoc > uoc_threshold;
	return irecord;
end;
$$ language plpgsql;


-- Q2: ...
create or replace view TranscriptRecordview1(unswid, cid, term, code, name, uoc, mark, grade)
AS
SELECT people.unswid, courses.id, right(cast(semesters.year as varchar), 2)||lower(semesters.term) as term,
subjects.code, subjects.name, subjects.uoc, course_enrolments.mark, course_enrolments.grade
FROM courses
INNER JOIN semesters ON courses.semester = semesters.id
INNER JOIN subjects ON subjects.id = courses.subject
INNER JOIN course_enrolments ON course_enrolments.course = courses.id
INNER JOIN people on people.id = course_enrolments.student
ORDER BY code, mark desc
;

-- UOC CALCULATION ONLY IF STUDENT PASSES
create or replace view TranscriptRecordView2
AS
SELECT *,
	CASE
		WHEN (grade = 'SY') or (grade = 'RS') or (grade = 'PT') or (grade = 'PC')
			or (grade = 'PS') or (grade = 'CR') or (grade = 'DN') or (grade = 'HD')
			or (grade = 'A') or (grade = 'B') or (grade = 'C') or (grade = 'D') or (grade = 'E')
			then uoc
		ELSE 0
	END AS uoc2
FROM TranscriptRecordview1
;

-- COUNTING TOTAL ENROLMENTS WITH NON-NULL VALUE
create or replace view TotalEnrolments
AS
SELECT cid,code, count(mark)
FROM TranscriptRecordView2
group by cid,code
;
-- JOIN TOTAL ENROLMENTS TO MAIN VIEW
create or replace view TranscriptRecordView3(unswid, cid, term, code, name, uoc2, mark, grade, rank,totalenrols)
AS
SELECT unswid, TranscriptRecordview2.cid, term, TranscriptRecordview2.code,
name, TranscriptRecordView2.uoc2, mark, grade,
(case when mark is not null then rank() over (PARTITION BY TranscriptRecordview2.cid order by mark desc nulls last)end),
count as totalEnrols
FROM TranscriptRecordview2
INNER JOIN TotalEnrolments ON TotalEnrolments.cid = TranscriptRecordview2.cid
;

-- FINAL VIEW TO INCLUDE RANK
create or replace view finalview
AS
SELECT unswid, TranscriptRecordview3.cid, term, TranscriptRecordview3.code,
name, uoc2, mark, grade, rank, totalEnrols
FROM TranscriptRecordview3
;

create type TranscriptRecord as (cid integer, term char(4), code char(8), name text, uoc integer, mark integer, grade char(2), rank integer, totalEnrols integer);

create or replace function Q2(stu_unswid integer)
	returns setof TranscriptRecord
as $$
begin
		RETURN QUERY SELECT cid::integer, term::char(4), code::char(8), name::text, uoc2::integer, mark::integer, grade::char(2), rank::integer, totalEnrols::integer
								 FROM finalview
								 WHERE unswid = $1;
		RETURN;
end;
$$ language plpgsql;

-- Q3: ...

-- BASE VIEW
create or replace view staff_records(staff_id, unswid, staff_name, teaching_records, count, offeredby, s_id)
AS
SELECT staff.id, people.unswid::integer, people.name::text, subjects.code,
count(subjects.code), subjects.offeredby, subjects.id
FROM people
INNER JOIN staff ON staff.id = people.id
INNER JOIN course_staff ON course_staff.staff = staff.id
INNER JOIN courses ON courses.id = course_staff.course
INNER JOIN subjects ON subjects.id = courses.subject
INNER JOIN staff_roles on staff_roles.id = course_staff.role
WHERE staff_roles.id != '3004'
GROUP BY staff.id, people.unswid, people.name, subjects.code, subjects.offeredby, subjects.id
;

create or replace view number_subjects(unswid, owner,count_subjects)
AS
SELECT staff_records.unswid::integer, orgunit_groups.owner::integer, count(staff_records.teaching_records)::integer
FROM staff_records
INNER JOIN orgunit_groups ON orgunit_groups.member = staff_records.offeredby
INNER JOIN orgunits ON orgunits.id = orgunit_groups.member
GROUP BY staff_records.unswid, orgunit_groups.owner
;

-- VIEW TO COUNT NUMBER OF DISTINCT SUBJECTS
create or replace view distinct_subjects(unswid, staff_name, s_id, teaching_records, count, name, member, owner)
AS
SELECT staff_records.unswid, staff_records.staff_name, staff_records.s_id,
staff_records.teaching_records, staff_records.count, orgunits.name,
staff_records.offeredby, orgunit_groups.owner
FROM staff_records
INNER JOIN orgunit_groups ON orgunit_groups.member = staff_records.offeredby
INNER JOIN orgunits ON orgunits.id = orgunit_groups.member
;

create or replace view teachingrecord_final(unswid, staff_name, s_id, teaching_records, count, name, owner, count_subjects)
AS
SELECT distinct_subjects.unswid, distinct_subjects.staff_name, distinct_subjects.s_id, distinct_subjects.teaching_records,
distinct_subjects.count, distinct_subjects.name, distinct_subjects.owner, number_subjects.count_subjects
FROM distinct_subjects
INNER JOIN number_subjects
	ON number_subjects.unswid = distinct_subjects.unswid
	AND number_subjects.owner = distinct_subjects.owner
ORDER BY distinct_subjects.s_id
;


create type TeachingRecord as (unswid integer, staff_name text, teaching_records text);

create or replace function Q3(org_id integer, num_sub integer, num_times integer)
	returns setof TeachingRecord
as $$
BEGIN
	RETURN QUERY SELECT unswid::integer, staff_name::text, string_agg(teaching_records::text||', '||count::text||', '||name::text||E'\n',null)
							 FROM teachingrecord_final
							 WHERE owner = $1 AND count_subjects > $2 AND count > $3
							 GROUP BY unswid, staff_name
							 ORDER BY staff_name;
	RETURN;
END;
$$ language plpgsql;
