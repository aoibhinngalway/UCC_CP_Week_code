include "globals.mzn";

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

