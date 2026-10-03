INSERT INTO room_types (name, description, price_per_night, max_adults, max_children) VALUES
  ('Habitación Sencilla', 'Cama queen, baño privado', 450.00, 2, 1),
  ('Habitación Familiar', 'Dos camas, ideal para familias', 750.00, 4, 2);

INSERT INTO rooms (room_type_id, room_number) VALUES
  (1, '101'), (1, '102'), (1, '103'),
  (2, '201'), (2, '202');
