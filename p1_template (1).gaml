/**
* Name: Template P1 Wumpus. ASM 24/25
* Author: Raul Fraile
* Tags: 
*/

model Wumpus_template

global {
	init {
		create goldArea number:1;
		create wumpusArea number: 1;
	}
}


grid gworld width: 25 height: 25 neighbors:4 {
	rgb color <- #green;
}



species odorArea{
	aspect base {
	  draw square(4) color: #brown border: #black;		
	}
}


species wumpusArea{
	init {
		gworld place <- one_of(gworld);
		location <- place.location;
		
		// Place it's a cell, so we can find its neighbors https://gama-platform.org/wiki/GridSpecies
		list<gworld> my_neighbors <- [];
		ask place {
			my_neighbors <- neighbors;
		}
		
		loop i over: my_neighbors {
			create odorArea{
				location <- i.location;
			}
		}
	}
	aspect base {
	  draw square(4) color: #red border: #black;		
	}
}

species glitterArea{
	aspect base {
	  draw square(4) color: #chartreuse border: #black;		
	}
}

species goldArea{
	init {
		gworld place <- one_of(gworld);
		location <- place.location;
		
		// Place it's a cell, so we can find its neighbours https://gama-platform.org/wiki/GridSpecies
		list<gworld> my_neighbors <- [];
		ask place {
			my_neighbors <- neighbors;
		}
		
		loop i over: my_neighbors {
			create glitterArea{
				location <- i.location;
			}
		}
	
	}
	
	aspect base {
	  draw square(4) color: #yellow border: #black;		
	}
}



experiment Wumpus_experiment_1 type: gui {
	/** Insert here the definition of the input and output of the model */
	output {					
		display view1 { 
			grid gworld border: #darkgreen;
			species goldArea aspect:base;
			species glitterArea aspect:base;
			species wumpusArea aspect:base;
			species odorArea aspect:base;

		}
	}
}
