# ----- CONFIGURE YOUR EDITOR TO USE 4 SPACES PER TAB ----- #
import pymysql as db
import settings
import sys

def connection():
    ''' User this function to create your connections '''
    con = db.connect(
        settings.mysql_host,
        settings.mysql_user,
        settings.mysql_passwd,
        settings.mysql_schema)

    return con

def updateRank(rank1, rank2, movieTitle):

    # Create a new connection
    con=connection()

    # Create a cursor on the connection
    cur=con.cursor()

    try:
        float(rank1)
    except ValueError:
        return [("status",),("error",),]
    try:
        float(rank2)
    except ValueError:
        return [("status",),("error",),]

    #get movie.rank
    cur.execute("select movie.rank from movie where movie.title=%s",(movieTitle,))
    rank=cur.fetchone()

    #calculate new rank
    if rank is None:        #no rank found or more than one ranks found
        return [("status",),("error",),]
    elif not rank[0]:       #rank found but its NULL
        newrank=(float(rank1)+float(rank2))/2
    else:                   #one rank found
        newrank=(float(rank1)+float(rank2)+rank[0])/3

    #update rank
    #(note: will not work if safe update is on, because no key is used in where)
    cur.execute("update movie set rank=%s where title=%s",(newrank,movieTitle,))
    if cur.rowcount!=1: #check if update was succesful
        return [("status",),("error",),]
    con.commit()
    return [("status",),("ok",)]


def colleaguesOfColleagues(actorId1, actorId2):

    # Create a new connection
    con=connection()
    
    # Create a cursor on the connection
    cur=con.cursor()

    #get a view for colleagues of actor1
    cur.execute("select distinct c.actor_id\
                from (actor as c) inner join (role as rolec) on c.actor_id=rolec.actor_id\
					                inner join (movie as mc) on rolec.movie_id=mc.movie_id\
                where c.actor_id!=%s and mc.movie_id IN (	select distinct movie.movie_id\
											                from actor inner join role on actor.actor_id=role.actor_id\
											                inner join movie on role.movie_id=movie.movie_id\
											                where actor.actor_id=%s)", (actorId1,actorId1))
    coll_1 = cur.fetchall()
    #get view for colleagues of actor2
    cur.execute("select distinct c.actor_id\
                from (actor as c) inner join (role as rolec) on c.actor_id=rolec.actor_id\
					                inner join (movie as mc) on rolec.movie_id=mc.movie_id\
                where c.actor_id!=%s and mc.movie_id IN (	select distinct movie.movie_id\
											                from actor inner join role on actor.actor_id=role.actor_id\
											                inner join movie on role.movie_id=movie.movie_id\
											                where actor.actor_id=%s)", (actorId2,actorId2))   
    coll_2 = cur.fetchall()

    #get colleagues of colleagues
    total=0
    results=[("movieTitle", "colleagueOfActor1", "colleagueOfActor2", "actor1","actor2"),] 
    for c1 in coll_1:
        for c2 in coll_2:
            if c1!=c2:
                cur.execute("select distinct m1.title\
                            from (movie as m1) 	inner join (role as r1) on m1.movie_id=r1.movie_id and r1.actor_id=%s,\
	                             (movie as m2)	inner join (role as r2) on m2.movie_id=r2.movie_id and r2.actor_id=%s\
                            where m1.movie_id=m2.movie_id", (c1[0],c2[0]))
                movietitles=cur.fetchall()  #movietitles where coll_1 played with coll_2
                for title in movietitles:
                   total = total+1
                   results.append((title[0],c1[0],c2[0],actorId1,actorId2),)
    print (total)
    return results

def actorPairs(actorId):

    # Create a new connection
    con=connection()
    
    # Create a cursor on the connection
    cur=con.cursor()
	

    #num of genres od actorId
    cur.execute("select count(distinct genre.genre_id)\
                from actor, role, movie, movie_has_genre, genre\
                where actor.actor_id=role.actor_id AND\
                      role.movie_id=movie.movie_id AND\
                      movie.movie_id=movie_has_genre.movie_id AND\
                      movie_has_genre.genre_id=genre.genre_id\
	                  AND actor.actor_id=%s", (actorId,))
    numgenres=cur.fetchone()
    

	#actors that only played diff genrs
    cur.execute("select distinct a1.actor_id, count(distinct g1.genre_id)\
                from actor a1, genre g1, role r1, movie_has_genre mhg1\
                where g1.genre_id=mhg1.genre_id AND mhg1.movie_id=r1.movie_id AND r1.actor_id=a1.actor_id AND NOT EXISTS (select g1.genre_id\
					                from genre g1, actor a2, role r1, movie_has_genre mhg1\
                                    where g1.genre_id=mhg1.genre_id AND mhg1.movie_id=r1.movie_id AND r1.actor_id=a1.actor_id \
                                    AND a2.actor_id=%s AND g1.genre_id IN (select g2.genre_id\
																                from genre g2,role r2,movie_has_genre mhg2 \
                                                                                where g2.genre_id=mhg2.genre_id AND mhg2.movie_id=r2.movie_id\
                                                                                AND a2.actor_id=r2.actor_id))\
                group by a1.actor_id", (actorId,))    
    actors=cur.fetchall()

    total=0
    results=[("actor2Id",)]
    for actor in actors:
        if (int(actor[1])+int(numgenres[0]))>=7:
            total=total+1
            results.append((actor[0],))
    
    return results
	
def selectTopNactors(n):

    # Create a new connection
    con=connection()
    
    # Create a cursor on the connection
    cur=con.cursor()
    
    #get all genres
    cur.execute("select genre.genre_id from genre")
    genres=cur.fetchall()
    #for every genre get top N actors
    results=[("genreName", "actorId", "numberOfMovies"),]
    for i in genres:
        #get genre name
        cur.execute("select genre.genre_name from genre where genre.genre_id=%s",(i[0],))
        gname=cur.fetchone()
        #get actorId and numberOfMovies he/she has with the genre
        cur.execute("select actor.actor_id, count(movie.movie_id)\
                    from actor 	inner join role on role.actor_id=actor.actor_id\
			                    inner join movie on movie.movie_id=role.movie_id\
			                    inner join movie_has_genre on movie_has_genre.movie_id=movie.movie_id\
			                    inner join genre on genre.genre_id=movie_has_genre.genre_id\
                    where genre.genre_id=%s\
                    group by actor.actor_id\
                    order by count(movie.movie_id) desc,actor.actor_id", (i[0],))
        #fetch n results
        for j in range(0,int(n)):
            r=cur.fetchone()
            if r is not None:
                results.append((gname[0],r[0],r[1]),)
    return results

