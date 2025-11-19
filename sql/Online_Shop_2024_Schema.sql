-- a new data type for email address
create extension if not exists CITEXT;

drop domain if exists email_type cascade;
create domain email_type as CITEXT;
alter domain email_type
	add constraint email_format check (value~'^[A-Za-z0-9]+@[A-Za-z]+.com$');

-- a new data type for the phone number
drop domain if exists customer_phone cascade;
create domain customer_phone as text
	check (value~'^[0-9]+-[0-9]+-[0-9]+$');

-- import customers.csv
drop table if exists customers cascade;

create table customers(
	customer_id bigint generated always as identity primary key,
	first_name char(32),
	last_name char(32),
	address text,
	email email_type,
	phone_number customer_phone
);

copy customers(customer_id, first_name, last_name, address, email, phone_number)
from '/Users/yingliu/Documents/GitHub/Online_Shop_2024_Postgresql/data/customers.csv'
delimiter ','
csv header;



-- import suppliers.csv
drop table if exists suppliers cascade;

create table suppliers(
	supplier_id bigint generated always as identity primary key,
	supplier_name text,
	contact_name text,
	address text,
	phone_number text check(phone_number~'^\([0-9]+\) [0-9]+-[0-9]+$'),
	email email_type
);

copy suppliers(supplier_id, supplier_name, contact_name, address, phone_number, email)
from '/Users/yingliu/Documents/GitHub/Online_Shop_2024_Postgresql/data/suppliers.csv'
delimiter ','
csv header;



-- import products.csv
drop table if exists products cascade;

create table products ( 
	product_id bigint generated always as identity primary key,
	product_name text,
	category text,
	price numeric,
	supplier_id bigint references suppliers(supplier_id)
		on delete cascade
		on update cascade
);

copy products(product_id, product_name, category, price, supplier_id)
from '/Users/yingliu/Documents/GitHub/Online_Shop_2024_Postgresql/data/products.csv'
delimiter ','
csv header;



-- import orders.csv
drop table if exists orders cascade;

create table orders (
	order_id bigint generated always as identity primary key,
	order_date date,
	customer_id bigint,
	total_price numeric,
	constraint customer_id_fk foreign key (customer_id) references customers(customer_id)
		on delete cascade 
		on update cascade
);


copy orders(order_id, order_date, customer_id, total_price)
from '/Users/yingliu/Documents/GitHub/Online_Shop_2024_Postgresql/data/orders.csv'
delimiter ','
csv header;


--import order_items.csv
drop table if exists order_items;

create table order_items( 
	order_item_id bigint generated always as identity primary key,
	order_id bigint references orders(order_id)
		on delete cascade
		on update cascade,
	product_id bigint,
	quantity int,
	price_at_purchase numeric,
	constraint product_id_fk foreign key (product_id) references products(product_id)
		on delete cascade 
		on update cascade
);

copy order_items(order_item_id, order_id, product_id, quantity, price_at_purchase)
from '/Users/yingliu/Documents/GitHub/Online_Shop_2024_Postgresql/data/order_items.csv'
delimiter ','
csv header;



-- import reviews.csv
drop table if exists reviews;

create table reviews (
	review_id bigint generated always as identity primary key,
	product_id bigint references products(product_id)
		on delete cascade
		on update cascade,
	customer_id bigint,
	rating int check(rating <= 5 and rating >=1),
	review_text text,
	review_date date,
	constraint customer_id_fk foreign key (customer_id) references customers(customer_id) 
		on delete cascade 
		on update cascade
);

-- create a trigger 
drop function if exists compare_review_date cascade;

create or replace function compare_review_date()
returns trigger as $$
declare
	reference_date date;
begin 
	select order_date into reference_date
	from orders
	where orders.customer_id=new.review_id;
	
	if new.review_date < reference_date then
		new.review_date := reference_date;
	end if;
	
	return new;
end;
$$ language plpgsql;

CREATE TRIGGER enforce_review_date
BEFORE INSERT OR UPDATE ON reviews
FOR EACH ROW
EXECUTE FUNCTION compare_review_date();

copy reviews(review_id, product_id, customer_id, rating, review_text, review_date)
from '/Users/yingliu/Documents/GitHub/Online_Shop_2024_Postgresql/data/reviews.csv'
delimiter ','
csv header;



-- import shipments.csv
drop table if exists shipments;

create table shipments ( 
	shipment_id bigint generated always as identity primary key,
	order_id bigint,
	shipment_date date,
	carrier varchar(32),
	tracking_number text,
	delivery_date date check (delivery_date >= shipment_date),
	shipment_status text,
	constraint order_id_fk foreign key (order_id) references orders(order_id)
		on delete cascade 
		on update cascade
);


drop function if exists check_shipment_date cascade;

create or replace function check_shipment_date()
returns trigger as $$
declare 
	reference_date date;
begin 
	select order_date into reference_date
	from orders
	where orders.order_id=new.order_id;

	if new.shipment_date < reference_date then 
		new.shipment_date := reference_date;
	end if;
	
	return new;
end;
$$ language plpgsql;

create trigger enforce_shipment_date
before insert or update on shipments
for each row
execute function check_shipment_date();

copy shipments(shipment_id, order_id, shipment_date, carrier, tracking_number, delivery_date, shipment_status)
from '/Users/yingliu/Documents/GitHub/Online_Shop_2024_Postgresql/data/shipments.csv'
delimiter ','
csv header;


-- import payment.csv
drop table if exists payments;

create table payments ( 
	payment_id bigint generated always as identity primary key,
	order_id bigint references orders(order_id)
		on delete cascade
		on update cascade,
	payment_method varchar(32),
	amount numeric,
	transaction_status varchar(32)
);

copy payments(payment_id, order_id, payment_method, amount, transaction_status)
from '/Users/yingliu/Documents/GitHub/Online_Shop_2024_Postgresql/data/payment.csv'
delimiter ','
csv header;




