-- FIX: Replace London £ prices with Port Harcourt ₦ prices
-- Run this ONCE in Supabase Dashboard > SQL Editor > New Query > Paste > Run

-- 1. Clear old basket test data (so we can delete menu safely)
delete from order_items;

-- 2. Clear old London menu
delete from products;

-- 3. Insert new PH menu in Naira
insert into products (category, name, description, image_url, is_veg, prices) values
('Pizzas','Farm House Xtreme Pizza','Double chicken, royal cheese, tandoori drizzle, fries crumbs','https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400', false, '{"Regular":8500,"Large":12500,"Family":15800}'),
('Pizzas','Deluxe Pizza','Loaded veggie deluxe with extra mozzarella','https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400', true, '{"Regular":9000,"Large":13000,"Family":16500}'),
('Pizzas','Tandoori Pizza','Smoky tandoori chicken, onions + peppers, raita swirl','https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400', false, '{"Regular":9500,"Large":13500,"Family":17000}'),
('Shawarma','Chicken Shawarma Wrap','Chargrilled chicken, garlic sauce, fries inside','https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=400', false, '{"Regular":3500,"Large":5000,"Family":9500}'),
('Grills & Kebabs','Seekh Kebab Plate','Chargrilled kebabs with naan + onions','https://images.unsplash.com/photo-1603894584373-5ac82b2d3a2d?w=400', false, '{"Regular":6500,"Large":9000,"Family":15000}'),
('Sides','Garlic Bread Supreme','Fresh baked garlic bread with mozzarella','https://images.unsplash.com/photo-1573140247632-f8fd74997d5c?w=400', true, '{"Regular":4000,"Large":5500,"Family":7500}'),
('Drinks','Coca Cola 50cl','Chilled bottle','https://images.unsplash.com/photo-1554866585-cd94860890b7?w=400', true, '{"Regular":1000,"Large":1500,"Family":2000}');

-- 4. Verify: should show 7 rows with Naira prices
select name, category, prices from products;
