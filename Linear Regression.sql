create table 
	fish_market(
		Species Varchar(50),
		weight numeric,
		length1 numeric,
		length2 numeric,
		length3 numeric,
		height numeric,
		width numeric
		)
;

select * from initial('width', 'length1')

create or replace function initial(x_pre text, y_pre text)
	returns table(
		predictor varchar,
		predictant varchar)
	language plpgsql
as $$
begin
	return query execute 'select ' || x_pre || '::varchar, ' || y_pre || '::varchar from fish_market';
end;
$$;

select * from initial('width', 'length1');

create or replace function linereg(dml text, edr text)
	returns table(
			a numeric,
			b numeric,
			Ro numeric)
	language plpgsql
as $$
begin
	return query
			select
					round((((Sy * Sxx) - (Sx * Sxy)) / ((N * Sxx)-(Sx * Sx))),2) as Alpha,
					round((((N * Sxy) - (Sx * Sy)) / ((N * Sxx) -(Sx * Sx))),2) as Beta,
					round((((N * Sxy) - (Sx * Sy)) / sqrt(((N * Sxx) - (Sx * Sx)) * ((N * Syy) - (Sy * Sy)))),2) as Ro
				from
					(select 
						sum(x) as Sx,
						sum(y) as Sy,
						sum(x * x) as Sxx,
						sum(x * y) as Sxy,
						sum(y * y) as Syy,
						count(*) as N
					from
						(select 
							cast(predictor as numeric) as x,
							cast(predictant as numeric) as y
						from 
							initial(dml, edr)) as values ) as totals 
							;
end;$$

select * from linereg('width','length1')

create or replace function outputs (ac numeric, b numeric, Ro numeric, dml text, edr text)
	returns table(
			x_ini numeric,
			y_ini numeric,
			y_est numeric)
	language plpgsql
as $$
begin
	return query
			select 
				x, 
				y, 
				(ac + b * x)
			from(
				select
					cast(predictor as numeric) as x,
					cast(predictant as numeric) as y
				from 
					initial(dml, edr)) as values
				;
end;$$

select * from outputs((select a from linereg('width', 'length1')), 
					  (select b from linereg('width', 'length1')), 
					  (select Ro from linereg('width', 'length1')),
					  'width',
					  'length1')

create or replace function lireg_statistics()
	returns table(
				Multiple_R numeric,
				R_square numeric,
				Adjusted_R_square numeric,
				Standard_error numeric,
				num numeric)
	language plpgsql
as $$
begin return query
		select
			((n * Sxy) - (Sx * Sy)) / sqrt(((n * Sxx) - (Sx * Sx)) * ((n * Syy) - (Sy * Sy))) as Mlt,
			1 - (Syiye2 / Syiya2) as Rsq,
			1 - (((1 - (1 - (Syiye2 /Syiya2))) * (n - 1)) / (n - 2)) as AdjRsq, -- (n - p - 1) p = 1
			sqrt((Syiye2) / n) as Stder,
			cast(n as numeric)
		from(
			select
					sum(x_ini) as Sx,
					sum(y_ini) as Sy,
					sum(x_ini * x_ini) as Sxx,
					sum(x_ini * y_ini) as Sxy,
					sum(y_ini * y_ini) as Syy,
					sum(power((y_ini - y_est),2)) as Syiye2,
					sum(power((y_ini - (avgyini)),2)) as Syiya2,
					count(*) as n
				from(
					select 
						x_ini,
						y_ini,
						y_est,
						avg(y_ini) over() as avgyini
					from 
						outputs((select a from linereg('width', 'length1')), 
								(select b from linereg('width', 'length1')), 
								(select Ro from linereg('width', 'length1')),
							   	'width',
							   	'length1')
					) as initial_values	
			) as initial_totals
		;
end $$;

select * from lireg_statistics()