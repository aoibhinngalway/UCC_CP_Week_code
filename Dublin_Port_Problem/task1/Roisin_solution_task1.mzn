include "globals.mzn";
include "ide/vis.mzn";

enum ShipType;
int:nrBerths;
array[1..nrBerths] of set of ShipType:berthType;
array[1..nrBerths] of int:berthLength; % in meters
array[1..nrBerths] of int:depth; % in centimeters

int:nrShips;
array[1..nrShips] of ShipType:shipType;
array[1..nrShips] of int:shipLength;  % in meters
array[1..nrShips] of int:draught; % in centimeters
array[1..nrShips] of int:arrival; % integer, 15min time resolution
array[1..nrShips] of int:departure; % integer, 15 min time resolution


include "monday2.dzn";


%
array[1..nrBerths, 1..nrShips] of var bool: assignments; % temperature at point (i,j)

%Constraint 1: 
%  One ship can only dock in one place.. so each column must be summed to one.
constraint forall (ship in 1..nrShips) (
              sum(berth in 1..nrBerths)(assignments[berth, ship]) = 1
           );

%Constraint 2:
%  Ship types must be the same as the berth type if a ship is assigned.
constraint forall(berth in 1..nrBerths)(
              forall(ship in 1..nrShips)(
              
                  %assignments[berth, ship] = 1 ->
                  %  (shipType[ship] in berthType[berth] /\
                  %  shipLength[ship] <= berthLength[berth] /\
                  %  draught[ship] <= depth[berth])     
                  
                  (shipType[ship] in berthType[berth] /\ 
                    shipLength[ship] <= berthLength[berth] /\ 
                    draught[ship] <= depth[berth]) \/ 
                 assignments[berth, ship] = 0
              )
           );
                                                                                                                                                       
%Constraint 5:
% checking the time overlaps..
constraint forall(berth in 1..nrBerths)(
              %for given berth, we look a ship.
              forall(ship in 1..nrShips)(
                 %for given berth and ship, we loop other ships .. and check if they overlap.
                 forall(other in 1..nrShips where other != ship)(
                 
                  %(assignments[berth, ship] = 1 /\ assignments[berth, other] = 1)  ->
                  %  departure[other] < arrival[ship] \/ arrival[other] > departure[ship]
                 
                    (departure[other] < arrival[ship]  \/ /*either, other ship arrives earlier*/
                     arrival[other] > departure[ship]) \/ /*or, other ship arrives late*/
                     assignments[berth, ship] + assignments[berth, other] <= 1 
                 )%forall
              )%forall
           );

array[1..nrBerths] of var int:span_durations = [
    if sum(ship in 1..nrShips)(assignments[berth, ship]) >= 1 then
        abs(
            max(ship in 1..nrShips)(if assignments[ship, berth] = 1 then departure[ship] else 0 endif) -
            min(ship in 1..nrShips)(if assignments[ship, berth] = 1 then arrival[ship] else 9999 endif)
        ) 
    else
        0
    endif | berth in 1..nrBerths ];

var int: total_span = sum(berth in 1..nrBerths)(span_durations[berth]);
  
%used for visualizing spans.
array[1..nrBerths] of var int:span_starts = [
    if sum(ship in 1..nrShips)(assignments[berth, ship]) >= 1 then
        min(ship in 1..nrShips)(if assignments[ship, berth] = 1 then arrival[ship] else 9999 endif) 
    else
        0
    endif |berth in 1..nrBerths];
    
array[1..nrBerths] of par string:span_labels = ["Berth \(berth)" | berth in 1..nrBerths];
       
     
                             
var int: lastest_departure = max(berth in 1..nrBerths)(
                                max(ship in 1..nrShips)(
                                  if assignments[ship, berth] = 1 then departure[ship] else 0 endif
                                )
                             );
                                                       
solve satisfy;

%solve minimize lastest_departure;
 
       
output ["\n\nAssignments:\n"] ++ 

       ["total span: " ++ show(total_span) ++ "\n"] ++
       ["lastest_departure: " ++ show(lastest_departure) ++ "\n"] ++
       
       [
        if ship = 1 then "\nBerth \(berth) " ++ "(type: " ++ show(berthType[berth]) ++ "):\n" else "" endif ++
          if fix(assignments[berth, ship] = 1) then 
            "  Ship #" ++ show(ship) ++ " (type: " ++ show(shipType[ship]) ++ ", " ++ 
                          "arrival: " ++ show(arrival[ship]) ++ ", " ++ 
                          "depature: " ++ show(departure[ship]) ++ ")" ++ "\n" 
          else "" endif 
        | berth in 1..nrBerths, ship in 1..nrShips 
       ] ++
       ["\n\n"] ++
       [ show_gantt(span_starts, span_durations, span_labels) ];

%starting web-based visualization.
constraint vis_gantt(span_starts, span_durations, span_labels);  