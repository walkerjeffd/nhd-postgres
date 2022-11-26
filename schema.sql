-- Create a derived table that has the denormalized results for just our serving
-- PostGIS 9.1 is smart enough to set up the spatial column metadata for us
create table flowlinesvaa as
  select
    nhdflowline.*, 
    plusflowlinevaa.hydroseq, 
    plusflowlinevaa.fromnode, 
    plusflowlinevaa.tonode
  from nhdflowline
  inner join plusflowlinevaa
  on nhdflowline.comid = plusflowlinevaa.comid
  where nhdflowline.ftype != 'Coastline';

-- -- indices on our derived table
-- create index rivers_geometry_gist on rivers using gist(geometry);
-- create index rivers_strahler_idx ON rivers(strahler);
-- create index rivers_gnis_id_idx on rivers(gnis_id);
-- create index rivers_huc8_idx on rivers(huc8);

-- -- analyze to give the query planner appropriate hints
-- vacuum analyze rivers;

-- -- we could drop these tables, but it's nice to leave them around
-- -- drop table nhdflowline;
-- -- drop table plusflowlinevaa;