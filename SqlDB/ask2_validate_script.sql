# --------------------------------------
# --------------------------------------
DROP PROCEDURE IF EXISTS ValidateQuery;
DELIMITER //
CREATE PROCEDURE ValidateQuery(IN qNum INT, IN queryTableName VARCHAR(255))
BEGIN
	DECLARE cname VARCHAR(64);
	DECLARE done INT DEFAULT FALSE;
	DECLARE cur CURSOR FOR SELECT c.column_name FROM information_schema.columns c WHERE 
c.table_schema='movies' AND c.table_name=queryTableName;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	# Add the column fingerprints into a tmp table
	DROP TABLE IF EXISTS cFps;
	CREATE TABLE cFps (
  	  `val` VARCHAR(50) NOT NULL
	) 
	ENGINE = InnoDB;

	OPEN cur;
	read_loop: LOOP
		FETCH cur INTO cname;
		IF done THEN
      			LEAVE read_loop;
    		END IF;
		
		DROP TABLE IF EXISTS ordered_column;
		SET @order_by_c = CONCAT('CREATE TABLE ordered_column as SELECT ', cname, ' FROM ', queryTableName, ' ORDER BY ', cname);
		PREPARE order_by_c_stmt FROM @order_by_c;
		EXECUTE order_by_c_stmt;
		
		SET @query = CONCAT('SELECT md5(group_concat(', cname, ', "")) FROM ordered_column INTO @cfp');
		PREPARE stmt FROM @query;
		EXECUTE stmt;

		INSERT INTO cFps values(@cfp);
		DROP TABLE IF EXISTS ordered_column;
	END LOOP;
	CLOSE cur;

	# Order fingerprints
	DROP TABLE IF EXISTS oCFps;
	SET @order_by = 'CREATE TABLE oCFps as SELECT val FROM cFps ORDER BY val'; 
	PREPARE order_by_stmt FROM @order_by;
	EXECUTE order_by_stmt;

	# Read the values of the result
	SET @q_yours = 'SELECT md5(group_concat(val, "")) FROM oCFps INTO @yours';
	PREPARE q_yours_stmt FROM @q_yours;
	EXECUTE q_yours_stmt;

	SET @q_fp = CONCAT('SELECT fp FROM fingerprints WHERE qnum=', qNum,' INTO @rfp');
	PREPARE q_fp_stmt FROM @q_fp;
	EXECUTE q_fp_stmt;

	SET @q_diagnosis = CONCAT('select IF(@rfp = @yours, "OK", "ERROR") into @diagnosis');
	PREPARE q_diagnosis_stmt FROM @q_diagnosis;
	EXECUTE q_diagnosis_stmt;

	INSERT INTO results values(qNum, @rfp, @yours, @diagnosis);

	DROP TABLE IF EXISTS cFps;
	DROP TABLE IF EXISTS oCFps;
END//
DELIMITER ;

# --------------------------------------

# Execute queries (Insert here your queries).

# Validate the queries
drop table if exists results;
CREATE TABLE results (
  `qnum` INTEGER  NOT NULL,
  `rfp` VARCHAR(50)  NOT NULL,
  `yours` VARCHAR(50)  NOT NULL,
  `diagnosis` VARCHAR(10)  NOT NULL
)
ENGINE = InnoDB;


# -------------
# Q1
drop table if exists q;
create table q as # Do NOT delete this line. Add the query below.

select title
from movie, role, actor, movie_has_genre, genre
where movie.movie_id=movie_has_genre.movie_id and movie_has_genre.genre_id=genre.genre_id and genre_name='Comedy'
and	movie.movie_id=role.movie_id and role.actor_id=actor.actor_id and actor.last_name='Allen';

CALL ValidateQuery(1, 'q');
drop table if exists q;
# -------------


# -------------
# Q2
drop table if exists q;
create table q as # Do NOT delete this line. Add the query below.

select movie.title, d.last_name
from actor, movie, role, director d, movie_has_director
where actor.last_name = 'Allen' AND actor.actor_id = role.actor_id 
	 AND movie_has_director.movie_id = movie.movie_id
	 AND role.movie_id = movie.movie_id 
	 AND d.director_id = movie_has_director.director_id 
     AND   (select count(distinct genre.genre_id) 
			from  movie_has_genre, genre,movie_has_director mhd
            where mhd.movie_id=movie_has_genre.movie_id AND 
                  mhd.director_id=d.director_id AND 
                  movie_has_genre.genre_id = genre.genre_id) > 1;

CALL ValidateQuery(2, 'q');
drop table if exists q;
# -------------


# -------------
# Q3
drop table if exists q;
create table q as # Do NOT delete this line. Add the query below.

select distinct a.last_name
from actor a, genre g, director d1
where d1.director_id IN 
(select d2.director_id  
from director d2,movie_has_director mhd2,movie m2,role r2
where d2.director_id=mhd2.director_id
	AND mhd2.movie_id=m2.movie_id  
	AND m2.movie_id=r2.movie_id AND r2.actor_id=a.actor_id 
	AND a.last_name=d2.last_name)
	AND d1.director_id IN 
	(select d3.director_id      
	from director d3,movie m3,movie_has_director mhd3,movie_has_genre mhg3,role r3
	where d3.director_id=mhd3.director_id AND mhd3.movie_id=m3.movie_id 
		AND m3.movie_id=mhg3.movie_id AND mhg3.genre_id=g.genre_id
		AND m3.movie_id=r3.movie_id AND r3.actor_id<>a.actor_id
    )
	AND g.genre_id IN (	select mhg4.genre_id                                                                    
						from movie m4,director d4,movie_has_director mhd4,movie_has_genre mhg4,role r4
						where a.actor_id=r4.actor_id AND r4.movie_id=m4.movie_id 
							AND m4.movie_id=mhd4.movie_id AND mhd4.director_id=d4.director_id
							AND a.last_name<>d4.last_name AND m4.movie_id=mhg4.movie_id ) ;

CALL ValidateQuery(3, 'q');
drop table if exists q;
# -------------


# -------------
# Q4
drop table if exists q;
create table q as # Do NOT delete this line. Add the query below.

select 'yes'
from movie, movie_has_genre, genre
where movie.movie_id=movie_has_genre.movie_id and movie_has_genre.genre_id=genre.genre_id	#inner join movie-genre
	and genre.genre_name='Drama' and movie.year=1995
having count(*)>0
UNION
select 'no'
from movie, movie_has_genre, genre
where movie.movie_id=movie_has_genre.movie_id and movie_has_genre.genre_id=genre.genre_id	#inner join movie-genre
	and genre.genre_name='Drama' and movie.year=1995
having count(*)=0;

CALL ValidateQuery(4, 'q');
drop table if exists q;
# -------------


# -------------
# Q5
drop table if exists q;
create table q as # Do NOT delete this line. Add the query below.

select d1.last_name as d1,d2.last_name as d2
	#from 2 sets of directors that worked on movies between 2000 and 2006
from (director as d1) 	inner join (movie_has_director as mhd1) on d1.director_id=mhd1.director_id
						inner join (movie as m1) on (mhd1.movie_id=m1.movie_id and m1.year between 2000 and 2006),
	 (director as d2) 	inner join (movie_has_director as mhd2) on d2.director_id=mhd2.director_id
						inner join (movie as m2) on (mhd2.movie_id=m2.movie_id and m2.year between 2000 and 2006)
where d1.director_id>d2.director_id 	#diff directors
	and m1.movie_id=m2.movie_id			#worked on the same movie
    and d1.director_id IN (	select director.director_id #director1 has worked on 6 distinct genres
							from director inner join movie_has_director on movie_has_director.director_id=director.director_id
										  inner join movie on movie_has_director.movie_id=movie.movie_id
										  inner join movie_has_genre on movie.movie_id=movie_has_genre.movie_id
										  inner join genre on movie_has_genre.genre_id=genre.genre_id
							group by director.director_id
							having count(distinct genre.genre_id)>=6
							)
	and d2.director_id IN (	select director.director_id #director2 has worked on 6 distinct genres
							from director inner join movie_has_director on movie_has_director.director_id=director.director_id
										  inner join movie on movie_has_director.movie_id=movie.movie_id
										  inner join movie_has_genre on movie.movie_id=movie_has_genre.movie_id
										  inner join genre on movie_has_genre.genre_id=genre.genre_id
							group by director.director_id
							having count(distinct genre.genre_id)>=6
							);

CALL ValidateQuery(5, 'q');
drop table if exists q;
# -------------


# -------------
# Q6
drop table if exists q;
create table q as # Do NOT delete this line. Add the query below.

select actor.first_name, actor.last_name, count(distinct director.director_id) as c
from actor 	inner join role on actor.actor_id=role.actor_id
			inner join movie on role.movie_id=movie.movie_id
			inner join movie_has_director on movie.movie_id=movie_has_director.movie_id
			inner join director on movie_has_director.director_id=director.director_id
group by actor.actor_id
having count(distinct movie.movie_id)=3;

CALL ValidateQuery(6, 'q');
drop table if exists q;
# -------------


# -------------
# Q7
drop table if exists q;
create table q as # Do NOT delete this line. Add the query below.

select genre.genre_id, count(distinct director.director_id) as c
from movie 	inner join movie_has_genre on movie.movie_id=movie_has_genre.movie_id
			inner join genre on movie_has_genre.genre_id=genre.genre_id
			inner join movie_has_director on  movie.movie_id=movie_has_director.movie_id
            inner join director on movie_has_director.director_id=director.director_id
where genre.genre_id IN (	select genre.genre_id	#genres of movies that have only one genre
							from movie 	inner join movie_has_genre on movie.movie_id=movie_has_genre.movie_id
										inner join genre on movie_has_genre.genre_id=genre.genre_id,
										movie_has_director, director
							where movie.movie_id IN (	select movie.movie_id	#movies that have on 1 genre
														from movie 	inner join movie_has_genre on movie.movie_id=movie_has_genre.movie_id
																	inner join genre on movie_has_genre.genre_id=genre.genre_id
														group by movie.movie_id
														having count(distinct genre.genre_id)=1
													)
							group by genre.genre_id
							
						)
group by genre.genre_id;

CALL ValidateQuery(7, 'q');
drop table if exists q;
# -------------


# -------------
# Q8
drop table if exists q;
create table q as # Do NOT delete this line. Add the query below.

select actor.actor_id
from actor 	inner join role on actor.actor_id=role.actor_id
			inner join movie on role.movie_id=movie.movie_id
            inner join movie_has_genre on movie.movie_id=movie_has_genre.movie_id
			inner join genre on movie_has_genre.genre_id=genre.genre_id,
	genre as g
group by actor.actor_id
having count(distinct genre.genre_id) = count(distinct g.genre_id);

CALL ValidateQuery(8, 'q');
drop table if exists q;
# -------------


# -------------
# Q9
drop table if exists q;
create table q as # Do NOT delete this line. Add the query below.

select g1.genre_id as a9,g2.genre_id as b9, count(distinct g1.director_id) as c9
from ((	select genre.genre_id,director.director_id #for every genre get its directors
		from genre 	inner join movie_has_genre on movie_has_genre.genre_id=genre.genre_id
					inner join movie on movie_has_genre.movie_id=movie.movie_id
					inner join movie_has_director on movie_has_director.movie_id=movie.movie_id
					inner join director on movie_has_director.director_id=director.director_id
		) as g1) inner join
	((	select genre.genre_id,director.director_id #for every genre get its directors
		from genre 	inner join movie_has_genre on movie_has_genre.genre_id=genre.genre_id
					inner join movie on movie_has_genre.movie_id=movie.movie_id
					inner join movie_has_director on movie_has_director.movie_id=movie.movie_id
					inner join director on movie_has_director.director_id=director.director_id
		) as g2)
		#pair the genres and for every pair keep only the common direcotors( dirsctors that did both genres)
        on (g1.genre_id<g2.genre_id and g1.director_id=g2.director_id)
group by g1.genre_id,g2.genre_id;

CALL ValidateQuery(9, 'q');
drop table if exists q;
# -------------

# -------------
# Q10
drop table if exists q;
create table q as # Do NOT delete this line. Add the query below.

select genre.genre_id, actor.actor_id, count(distinct movie.movie_id) as c10
from actor 	inner join role on actor.actor_id=role.actor_id
			inner join movie on role.movie_id=movie.movie_id
            inner join movie_has_genre on movie.movie_id=movie_has_genre.movie_id
            inner join genre on genre.genre_id=movie_has_genre.genre_id
where movie.movie_id NOT IN (select movie.movie_id	#movies that were directed by ...
							from movie 	inner join movie_has_director on movie_has_director.movie_id=movie.movie_id
										inner join director on director.director_id=movie_has_director.director_id
							where director.director_id IN (	select director.director_id	#...directors that directed more than one genre
																from director 	inner join movie_has_director on director.director_id=movie_has_director.director_id
																				inner join movie on movie.movie_id=movie_has_director.movie_id
																				inner join movie_has_genre on movie_has_genre.movie_id=movie.movie_id
																				inner join genre on movie_has_genre.genre_id=genre.genre_id
																group by director.director_id
																having count(distinct genre.genre_id)>1
														)
						)
group by genre.genre_id,actor.actor_id;

CALL ValidateQuery(10, 'q');
drop table if exists q;
# -------------

DROP PROCEDURE IF EXISTS RealValue;
DROP PROCEDURE IF EXISTS ValidateQuery;
DROP PROCEDURE IF EXISTS RunRealQueries;