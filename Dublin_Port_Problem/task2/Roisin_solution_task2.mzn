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

include "monday3.dzn";

int:maxWaitTime;


maxWaitTime = 24 * 60 - max(ship in 1..nrShips)(departure[ship]);

% DVs....
array[1..nrShips, 1..nrBerths] of var bool: assignments; 
array[1..nrShips] of var 0..maxWaitTime: waittime;


%Constraint 1: 
%  One ship can only dock in one place.. so each column must be summed to one.
constraint forall (ship in 1..nrShips) (
              sum(berth in 1..nrBerths)(assignments[ship, berth]) = 1
           );


constraint forall (ship in 1..nrShips) (
    waittime[ship] >= 0 /\ waittime[ship] < maxWaitTime
);


% Constraint set 2:
%   Ship types must be the same as the berth type if a ship is assigned.
%   The ship is smaller than the length of the berth
%   The draught of the ship is less than the depth of water in the berth.
%   A berth can have no any ship, it's good as well.
constraint   forall(ship in 1..nrShips)(
              forall(berth in 1..nrBerths)(
              
                  assignments[ship, berth] = 1 -> 
                    (shipType[ship] in berthType[berth] /\
                     shipLength[ship] <= berthLength[berth] /\
                     draught[ship] <= depth[berth]) 
                     
              )
           );


% Constraint: priority
% Some ships or ship types may get priority treatment, we are more likely to delay a bulk freighter than a passenger liner, 
% and capacity problems for LoLo ships should not affect the RoRo ferries.
constraint forall(berth in 1..nrBerths)(
              forall(ship in 1..nrShips)(
                  forall(other in 1..nrShips where other != ship)(
                      if assignments[ship, berth] + assignments[other, berth] > 1 then
                          (shipType[ship] = Cruise /\ shipType[other] != Cruise) -> waittime[ship] <= waittime[other]
                      else
                          true
                      endif
                  )
              )
           );


%
% Constraint
% wait time must be fair among same ship types.

constraint forall(berth in 1..nrBerths)(
              forall(ship in 1..nrShips)(
                  forall(other in 1..nrShips where other != ship)(
              
                    if assignments[ship, berth] = 1 then
                      (shipType[ship] = shipType[other]) ->
              
                        (arrival[ship] < arrival[other] /\ arrival[ship] + waittime[ship] <= arrival[other] + waittime[other]) \/
                        (arrival[ship] > arrival[other] /\ arrival[ship] + waittime[ship] >= arrival[other] + waittime[other])
                    else
                      true
                    endif
                  )
              )
          );



%include "alldifferent.mzn";
%constraint alldifferent();


%  checking the time overlaps..
constraint forall(berth in 1..nrBerths)(
              %for given berth, we look a ship.
              forall(ship in 1..nrShips)(
                  %for given berth and ship, we loop other ships .. and check if they overlap.
                  forall(other in 1..nrShips where other != ship)(
                      /*the other ship must be either left side or right side*/
                      assignments[ship, berth] + assignments[other, berth] > 1 ->
                      (departure[other] + waittime[other] <= arrival[ship] + waittime[ship] \/ /*either, other ship arrives earlier*/
                      arrival[other] + waittime[other] >= departure[ship] + waittime[ship]) /*or, other ship arrives late.*/
                  )
              )
           );


constraint forall(berth in 1..nrBerths)(
              %for given berth, we look a ship.
              forall(ship in 1..nrShips)(
                assignments[ship, berth] = 1 -> departure[ship] + waittime[ship] <= 24*60   
              )
           );

/*
array[1..nrBerths] of var int:spans = [
    if sum(ship in 1..nrShips)(assignments[ship, berth]) >= 1 then
        abs(
            max(ship in 1..nrShips)(if assignments[ship, berth] = 1 then departure[ship] + waittime[ship] else 0 endif) -
            min(ship in 1..nrShips)(if assignments[ship, berth] = 1 then arrival[ship] + waittime[ship] else 24*60 endif)
        ) 
    else
        0
    endif | berth in 1..nrBerths ];
    */
    
array[1..nrBerths] of var int:span_durations = [
    if sum(ship in 1..nrShips)(assignments[ship, berth]) >= 1 then
        abs(
            max(ship in 1..nrShips)(if assignments[ship, berth] = 1 then departure[ship] else 0 endif) -
            min(ship in 1..nrShips)(if assignments[ship, berth] = 1 then arrival[ship] else 9999 endif)
        ) 
    else
        0
    endif | berth in 1..nrBerths ];

  
%used for visualizing spans.
array[1..nrBerths] of var int:span_starts = [
    if sum(ship in 1..nrShips)(assignments[berth, ship]) >= 1 then
        min(ship in 1..nrShips)(if assignments[ship, berth] = 1 then arrival[ship] else 9999 endif) 
    else
        0
    endif |berth in 1..nrBerths];
    

var int: lastest_departure = max(berth in 1..nrBerths)(
                                max(ship in 1..nrShips)(
                                  if assignments[ship, berth] = 1 then departure[ship] + waittime[ship] else 0 endif
                                )
                             );

var int: total_span = sum(berth in 1..nrBerths)(span_durations[berth]);
var int: total_wait = sum(ship in 1..nrShips)(waittime[ship]);

array[1..nrBerths] of par string:span_labels = ["Berth \(berth)" | berth in 1..nrBerths];

%solve minimize total_span;
%solve minimize total_wait;
solve minimize lastest_departure;


output ["\n\nAssignments:\n"] ++ 
       
       ["\nwaittime: " ++ show(waittime) ++ "\n"] ++
       ["total wait: " ++ show(total_wait) ++ "\n"] ++
       
       ["span_starts: " ++ show(span_starts) ++ "\n"] ++
       ["span_durations: " ++ show(span_durations) ++ "\n"] ++
       
       ["total_span: " ++ show(total_span) ++ "\n"] ++
       ["lastest_departure: " ++ show(lastest_departure) ++ "\n"] ++
       
       [
        if ship = 1 then "\nBerth \(berth): \n" else "" endif ++
          if fix(assignments[ship, berth] = 1) then 
            "  Ship #" ++ show(ship) ++ " (wait: " ++ show(waittime[ship]) ++ "," ++ 
                          "scheduled arrival: " ++ show(arrival[ship] + waittime[ship]) ++ ", " ++ 
                          "scheduled depature: " ++ show(departure[ship] + waittime[ship]) ++ ")" ++ "\n" 
          else "" endif 
        | berth in 1..nrBerths, ship in 1..nrShips 
       ] ++
       ["\n\nBerth load span:\n\n"] ++
       [ fix(show_gantt(span_starts, span_durations, span_labels)) ];
    
%starting web-based visualization.
constraint vis_gantt(span_starts, span_durations, span_labels);  