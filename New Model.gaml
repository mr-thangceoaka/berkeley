model Traffic3Nodes

import "Traffic.gaml"

global {
	float seed <- 42.0;
	float traffic_light_interval <- 30#s;
	float step <- 0.2#s;

	file shp_roads <- file("../includes/roads.shp");
	file shp_nodes <- file("../includes/node.shp");

	geometry shape <- envelope(shp_roads) + 50;
	
	int initial_cars <- 10;
	int initial_motorbikes <- 20;
	
	float car_spawn_rate <- 0.02;
	float motorbike_spawn_rate <- 0.05;
	int max_cars <- 40;
	int max_motorbikes <- 80;
	
	float lane_width <- 3.5;

	graph road_network;
	list<intersection> non_deadend_nodes;

	init {
		write "===== BẮT ĐẦU KHỞI TẠO =====";
		
		create road from: shp_roads {
			int lanes_from_shp <- int(read("lanes"));
			num_lanes <- (lanes_from_shp > 0) ? lanes_from_shp : 2;
			maxspeed <- 60 #km/#h;
			create road {
				num_lanes <- myself.num_lanes;
				shape <- polyline(reverse(myself.shape.points));
				maxspeed <- myself.maxspeed;
				linked_road <- myself;
				myself.linked_road <- self;
			}
		}
		
		create intersection from: shp_nodes with: [is_traffic_signal :: true] {
			time_to_change <- traffic_light_interval;
			color <- #blue;
		}
		
		map edge_weights <- road as_map (each::each.shape.perimeter);
		road_network <- as_driving_graph(road, intersection) with_weights edge_weights;
		
		non_deadend_nodes <- intersection where !empty(each.roads_out);
		
		ask intersection { do initialize; }
		
		create motorbike_random number: initial_motorbikes;
		create car_random number: initial_cars;
		write "===== KHỞI TẠO HOÀN TẤT =====";
	}
	
	reflex spawn_vehicles {
		if (flip(motorbike_spawn_rate) and length(motorbike_random) < max_motorbikes) {
			create motorbike_random number: rnd(1, 3);
		}
		
		if (flip(car_spawn_rate) and length(car_random) < max_cars) {
			create car_random number: rnd(1, 2);
		}
	}
}

species vehicle_random parent: base_vehicle {
	init {
		road_graph <- road_network;
		if (flip(0.5)) { location <- one_of(non_deadend_nodes).location; } 
		else { 
			road random_road <- one_of(road);
			location <- any_location_in(random_road);
		}
		right_side_driving <- true;
	}

	reflex relocate when: next_road = nil and distance_to_current_target = 0.0 {
		do unregister;
		if (flip(0.7)) { location <- one_of(non_deadend_nodes).location; } 
		else { location <- any_location_in(one_of(road)); }
	}
	
	reflex commute {
		do drive_random graph: road_graph;
	}
}

species motorbike_random parent: vehicle_random {
	rgb body_color;
	rgb helmet_color;
	
	init {
		vehicle_length <- 1.8 #m + rnd(0.4);
		num_lanes_occupied <- 1;
		max_speed <- (30 + rnd(20)) #km/#h;
		
		body_color <- one_of([#red, #blue, #black, #white, #orange, #yellow, #green, #silver]);
		helmet_color <- one_of([#red, #blue, #yellow, #white, #black, #pink, #green]);

		proba_block_node <- 0.0;
		proba_respect_priorities <- 0.8 + rnd(0.2);
		proba_respect_stops <- [0.9 + rnd(0.1)];
		proba_use_linked_road <- rnd(0.7);
		lane_change_limit <- 2;
		linked_lane_limit <- 2;
		current_lane <- rnd(0, 1);
	}
	
	aspect base {
		if (current_road != nil) {
			point pos <- compute_position();
			
			draw ellipse(1.6, 0.7) at: pos color: body_color border: rgb(body_color.red * 0.6, body_color.green * 0.6, body_color.blue * 0.6) rotate: heading;
			
			point seat_pos <- {
				pos.x - cos(heading) * 0.3,
				pos.y - sin(heading) * 0.3
			};
			draw rectangle(0.6, 0.5) at: seat_pos color: #black rotate: heading;
			
			point rider_pos <- {
				pos.x - cos(heading) * 0.1,
				pos.y - sin(heading) * 0.1
			};
			draw circle(0.35) at: rider_pos color: helmet_color border: #black;
			
			point handlebar_start <- {
				pos.x + cos(heading) * 0.6 - sin(heading) * 0.25,
				pos.y + sin(heading) * 0.6 + cos(heading) * 0.25
			};
			point handlebar_end <- {
				pos.x + cos(heading) * 0.6 + sin(heading) * 0.25,
				pos.y + sin(heading) * 0.6 - cos(heading) * 0.25
			};
			draw line([handlebar_start, handlebar_end]) width: 0.3 color: #darkgray;
			
			point headlight_pos <- {
				pos.x + cos(heading) * 0.8,
				pos.y + sin(heading) * 0.8
			};
			draw triangle(0.3) at: headlight_pos color: #yellow rotate: heading + 90 border: #orange;
		}
	}
}

species car_random parent: vehicle_random {
	rgb body_color;
	rgb window_color;
	
	init {
		vehicle_length <- 4.0 #m + rnd(1.0);
		num_lanes_occupied <- 1;
		max_speed <- (40 + rnd(20)) #km/#h;
		
		body_color <- one_of([#black, #white, #silver, #darkblue, #darkred, #darkgreen, #gray, #brown]);
		window_color <- rgb(50, 50, 80, 200);
				
		proba_block_node <- 0.0;
		proba_respect_priorities <- 0.9 + rnd(0.1);
		proba_respect_stops <- [0.95 + rnd(0.05)];
		proba_use_linked_road <- 0.0;
		lane_change_limit <- 2;
		linked_lane_limit <- 0;
		current_lane <- rnd(0, 1);
	}
	
	aspect base {
		if (current_road != nil) {
			point pos <- compute_position();
			
			draw rectangle(vehicle_length, 1.8) at: pos color: body_color border: rgb(body_color.red * 0.5, body_color.green * 0.5, body_color.blue * 0.5) rotate: heading;
			
			point windshield_pos <- {
				pos.x + cos(heading) * (vehicle_length * 0.15),
				pos.y + sin(heading) * (vehicle_length * 0.15)
			};
			draw rectangle(vehicle_length * 0.4, 1.4) at: windshield_pos color: window_color rotate: heading;
			
			point light_left <- {
				pos.x + cos(heading) * (vehicle_length / 2) - sin(heading) * 0.6,
				pos.y + sin(heading) * (vehicle_length / 2) + cos(heading) * 0.6
			};
			draw circle(0.25) at: light_left color: #yellow border: #orange;
			
			point light_right <- {
				pos.x + cos(heading) * (vehicle_length / 2) + sin(heading) * 0.6,
				pos.y + sin(heading) * (vehicle_length / 2) - cos(heading) * 0.6
			};
			draw circle(0.25) at: light_right color: #yellow border: #orange;
			
			point rear_light_left <- {
				pos.x - cos(heading) * (vehicle_length / 2) - sin(heading) * 0.6,
				pos.y - sin(heading) * (vehicle_length / 2) + cos(heading) * 0.6
			};
			draw circle(0.2) at: rear_light_left color: #red border: #darkred;
			
			point rear_light_right <- {
				pos.x - cos(heading) * (vehicle_length / 2) + sin(heading) * 0.6,
				pos.y - sin(heading) * (vehicle_length / 2) - cos(heading) * 0.6
			};
			draw circle(0.2) at: rear_light_right color: #red border: #darkred;
		}
	}
}

experiment traffic_3nodes type: gui {
	parameter "Số xe hơi ban đầu" var: initial_cars min: 0 max: 50;
	parameter "Số xe máy ban đầu" var: initial_motorbikes min: 0 max: 100;
	parameter "Tỷ lệ sinh xe hơi" var: car_spawn_rate min: 0.0 max: 0.1 step: 0.01;
	parameter "Tỷ lệ sinh xe máy" var: motorbike_spawn_rate min: 0.0 max: 0.2 step: 0.01;
	parameter "Max xe hơi" var: max_cars min: 10 max: 100;
	parameter "Max xe máy" var: max_motorbikes min: 20 max: 200;
	parameter "Chu kỳ đèn" var: traffic_light_interval min: 10#s max: 120#s;
	
	output synchronized: true {
		display main_map type: 2d background: rgb(40, 40, 40) {
			species road aspect: base;
			species intersection aspect: base;
			species car_random aspect: base;
			species motorbike_random aspect: base;
		}
		
		monitor "Số xe hơi" value: length(car_random);
		monitor "Số xe máy" value: length(motorbike_random);
		monitor "Tổng xe" value: length(vehicle_random);
	}
}
