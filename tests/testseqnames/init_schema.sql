CREATE TABLE table1(
  id		SERIAL		PRIMARY KEY, 
  data		TEXT
);

CREATE TABLE table2(
  id		SERIAL		UNIQUE NOT NULL, 
  table1_id	INT4		REFERENCES table1(id) 
					ON UPDATE CASCADE ON DELETE CASCADE, 
  data		TEXT
);

CREATE TABLE table3(
  id		SERIAL,
  table2_id	INT4		REFERENCES table2(id)
					ON UPDATE SET NULL ON DELETE SET NULL,
  mod_date	TIMESTAMPTZ	NOT NULL DEFAULT now(),
  data		FLOAT		NOT NULL DEFAULT random()
  CONSTRAINT table3_date_check	CHECK (mod_date <= now())
); 

-- Create some Evil names...
create schema "Schema.name";
create schema "Studly Spacey Schema";
create sequence public."Evil Spacey Sequence Name";
create sequence "Studly Spacey Schema"."user";
create sequence "Schema.name"."a.periodic.sequence";
