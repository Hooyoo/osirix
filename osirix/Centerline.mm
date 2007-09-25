//
//  Centerline.mm
//  OsiriX
//
//  Created by Lance Pysher on 9/17/07.

/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
	 
	 
	Centerline extracts the centerline from a volume using thinning of the extracted surface
	Used to created automated fly through for virtual endoscopy
=========================================================================*/

#import "Centerline.h"
#import "OSIPoint3D.h"

#define id Id

//#include "vtkSurfaceReconstructionFilter.h"
#include "vtkReverseSense.h"

#include "vtkShrinkFilter.h"
#include "vtkDelaunay3D.h"
#include "vtkDelaunay2D.h"
#include "vtkProperty.h"


#include "vtkActor.h"
#include "vtkOutlineFilter.h"
#include "vtkImageReader.h"
#include "vtkImageImport.h"
#include "vtkCamera.h"
#include "vtkStripper.h"
#include "vtkLookupTable.h"
#include "vtkImageDataGeometryFilter.h"
#include "vtkProperty.h"
#include "vtkPolyDataNormals.h"
#include "vtkContourFilter.h"
#include "vtkImageData.h"

#include "vtkExtractPolyDataGeometry.h"
#include "vtkPolyDataConnectivityFilter.h"
#include "vtkTransformPolyDataFilter.h"

#include "vtkImageResample.h"
#include "vtkDecimatePro.h"
#include "vtkSmoothPolyDataFilter.h"

#include "vtkPolyDataNormals.h"

#include "vtkTextureMapToSphere.h"
#include "vtkTransformTextureCoords.h"
#include "vtkPowerCrustSurfaceReconstruction.h"
#include "vtkTriangleFilter.h"

#undef id

@implementation Centerline




- (NSArray *)generateCenterline:(vtkPolyData *)polyData startingPoint:(OSIPoint3D *)start endingPoint:(OSIPoint3D *)end{
	NSMutableArray *connectedPoints = [NSMutableArray array];
	NSMutableArray *stack = [NSMutableArray array];
	NSMutableArray *outputArray = [NSMutableArray array];

	vtkDecimatePro *decimate = 0L;
	vtkDecimatePro *decimate2 = 0L;
	vtkDataSet*	output = 0L;
	
	BOOL atEnd = NO;
	
	OSIPoint3D *endingPoint;
	OSIPoint3D *startingPoint;
	
	float voxelWidth = start.voxelWidth;
	float voxelHeight = start.voxelHeight;
	float voxelDepth = start.voxelDepth;



	int oPoints = polyData->GetNumberOfPoints();
	NSLog(@"original Points: %d", oPoints);
	NSLog(@"original Polys: %d", polyData->GetNumberOfPolys());
	vtkPolyData *medialSurface;
	//power->Update();
	//medialSurface = power->GetMedialSurface();
	
	float reduction = 0.8;
	NSLog(@"Decimate: %f", reduction);
	decimate = vtkDecimatePro::New();
	//decimate->SetInput(medialSurface);
	decimate->SetInput(polyData);
	decimate->SetTargetReduction(reduction);
	decimate->SetPreserveTopology(YES);
	decimate->BoundaryVertexDeletionOn();
	decimate->SplittingOn();
	decimate->SetMaximumError(VTK_DOUBLE_MAX);
	decimate->Update();
	


	
	vtkPolyData *data = decimate->GetOutput();
	int nPoints = data->GetNumberOfPoints();
	vtkPoints *medialPoints = data->GetPoints();
	NSLog(@"number of Points: %d", nPoints);
	NSLog(@"number of Polys: %d", data->GetNumberOfPolys());
	NSLog(@"Build Links");
	data->BuildLinks();


	vtkIdType i;
	int j, k, neighbors;			
	double x , y, z;
	// get all cells around a point
	data->BuildCells();
	
	// Thinning Needs to be fast.  Paper says iterate 1000
	NSMutableArray *pointArray = [NSMutableArray array];
	 
	for (i = 0; i < nPoints; i++) {	
		double *position = medialPoints->GetPoint(i);
		OSIPoint3D *point3D = [OSIPoint3D pointWithX:position[0]  y:position[1]  z:position[2] value:nil];
		[point3D setUserInfo:[self connectedPointsForPoint:i fromPolyData:data]];
		[pointArray addObject:point3D];
	}
	
	NSArray *originalPoints = [[pointArray copy] autorelease];

	NSLog(@"thinning NSArray" );
	for (int a = 0; a < 500 ;  a++){
		for (OSIPoint3D *point3D in pointArray) {
			x = point3D.x;
			y = point3D.y;
			z = point3D.z;
			
			NSSet *ptSet = [point3D userInfo];
			for (NSNumber *number in ptSet) {
				OSIPoint3D *nextPoint = [pointArray objectAtIndex:[number intValue]];
				x += nextPoint.x;
				y += nextPoint.y;
				z += nextPoint.z;			
			}
			neighbors = [ptSet count] + 1;		
			// get average
			x /= neighbors;
			y /= neighbors;
			z /= neighbors;
			
			[point3D setX:(float)x y:(float)y z:(float)z];
			
		}
	}
	NSLog(@"end Thinning NSArray");
	

	

	NSLog(@"find starting Point");
	// Find most inferior Point. Rrpresent Rectum
	// Could be a seed point to generalize.  

	x = [start x];
	y = [start y];
	z = [start z];
	
	double minDistance = 1000000;
	for (OSIPoint3D *point3D in pointArray) {
		double distance = sqrt( pow((x - point3D.x) * voxelWidth,2) + pow((y - point3D.y) * voxelHeight,2) + pow((z - point3D.z) * voxelDepth,2));
		if (distance < minDistance) {
			minDistance = distance;
			startingPoint = point3D;
		}
	}
	
	
	if (end) {
		x = [end x];
		y = [end y];
		z = [end z];
		for (OSIPoint3D *point3D in pointArray) {
			double distance = sqrt( pow((x - point3D.x) * voxelWidth,2) + pow((y - point3D.y) * voxelHeight,2) + pow((z - point3D.z) * voxelDepth,2));
			if (distance < minDistance) {
				minDistance = distance;
				endingPoint = point3D;
			}
		}
	}
	
	
	int startIndex = [pointArray indexOfObject:startingPoint];

	//double *sp = medialPoints->GetPoint(startingPoint);
	NSLog(@"seed: %@", start);
	NSLog(@"starting Point %@",startingPoint);
	//get connected Points
	
	
	
		//set array to 0
	unsigned char visited[nPoints];
	for (int i = 0; i < nPoints; i++) visited[i] = 0;
	
	visited[startIndex] = 1;
	[stack  addObject:[NSNumber numberWithInt:startIndex]];
	NSLog(@"get centerline Points");
	vtkIdType currentPoint;

	
	int count = 0;
	int currentModelIndex = startIndex; 
	OSIPoint3D *currentModelPoint = startingPoint;
	x = startingPoint.x; 
	y = startingPoint.y;
	z = startingPoint.z;
	
	while (([stack count] > 0 ) && !atEnd) {

		neighbors = 0;
		currentPoint = [[stack lastObject] intValue];
		[stack removeLastObject];

	
		//NSLog(@"get neighbors");
		//Loop through neighbors to get avg neighbor position Go three connections out
		NSSet *ptSet = [self connectedPointsForPoint:currentPoint fromPolyData:data];
		NSMutableSet *neighbors = [NSMutableSet set];
		[neighbors unionSet:ptSet];
		/*
		for (int i = 0; i < 2; i++) {
			NSMutableSet *newNeighbors = [NSMutableSet set];
			for (NSNumber *number in neighbors)  {
				NSSet *neighborSet = (NSSet *)[[pointArray objectAtIndex:[number intValue]] userInfo];
				[newNeighbors unionSet:neighborSet];
			}
			[neighbors unionSet:newNeighbors];
		}
		*/
		

		double modellingDistance = 5.0;

		for (NSNumber *number in neighbors)  {
			int index = [number intValue];
			OSIPoint3D *nextPoint = [pointArray objectAtIndex:index];
			
			if (visited[index] == 0) {
				double distance = sqrt( pow((x - nextPoint.x) * voxelWidth,2) + pow((y - nextPoint.y) * voxelHeight,2) + pow((z - nextPoint.z) * voxelDepth,2));
				//NSLog(@"distance: %f visited: %d", distance,  visited[pt]);
				
				if (distance > modellingDistance) {
					// if point is within modelling distance of an existing point don't add					
					BOOL tooClose = NO;
					for (OSIPoint3D *existingPoint in connectedPoints) {						
						if (sqrt( pow((currentModelPoint.x - existingPoint.x) * voxelWidth,2)
							+ pow((currentModelPoint.y - existingPoint.y) * voxelHeight,2)
							+ pow((currentModelPoint.z - existingPoint.z) * voxelDepth,2)) <  modellingDistance) tooClose = YES;
					}
					if (!tooClose) [connectedPoints addObject:currentModelPoint];
					
					if ([currentModelPoint isEqual:endingPoint]) {
						atEnd = YES;
						break;
					}
					currentModelIndex = index;
					currentModelPoint = nextPoint;
					x = nextPoint.x; 
					y = nextPoint.y;
					z = nextPoint.z;
				}
				[stack addObject:[NSNumber numberWithInt:index]];
				visited[index] = 1;
			}
			
		}				
		// try and make sure visited most points
		// Find next closest point
	}
	
	NSLog(@"npoints: %d", nPoints);	
	NSLog(@"connected Points: %d", [connectedPoints count]);
	
	// Arrange points from start to end based on proximity
	NSMutableArray *arrangedPoints = [NSMutableArray array];
	[arrangedPoints addObject:startingPoint];
	[connectedPoints removeObject:startingPoint];
	OSIPoint3D *nextPoint;
	currentModelPoint = startingPoint;
	
	while ([connectedPoints count] > 1) {
		minDistance = 1000000;
		for (OSIPoint3D *point3D in connectedPoints) {
			double distance = sqrt( pow((currentModelPoint.x - point3D.x) * voxelWidth,2)
				+ pow((currentModelPoint.y - point3D.y) * voxelHeight,2)
				+ pow((currentModelPoint.z - point3D.z) * voxelDepth,2));
			if (distance < minDistance) {
					minDistance = distance;
					nextPoint = point3D;
			}							
		}

		[arrangedPoints addObject:nextPoint];
		[connectedPoints removeObject:nextPoint];		
		currentModelPoint = nextPoint;
	}

	[arrangedPoints addObject:[connectedPoints lastObject]];
	
	NSLog(@"arranged Points: %d", [arrangedPoints count]);
	
	// Get all points lying between our selected points.  
	//Get points from original surface.  
	//Get average for centerline
	NSMutableArray *centerlinePoints = [NSMutableArray array];
	int pointCount = [arrangedPoints count] - 1;
	
	for (int i = 0; i < pointCount; i++) {
		NSMutableSet *nearbyPoints = [NSMutableSet set];
		OSIPoint3D *firstPoint = [arrangedPoints objectAtIndex:i];
		OSIPoint3D *nextPoint = [arrangedPoints objectAtIndex: i+1];
		double distance = sqrt( pow((firstPoint.x - nextPoint.x) * voxelWidth,2)
				+ pow((firstPoint.y - nextPoint.y) * voxelHeight,2)
				+ pow((firstPoint.z - nextPoint.z) * voxelDepth,2));
		for (OSIPoint3D *point3D in pointArray) {
			double distance1 = sqrt( pow((firstPoint.x - point3D.x) * voxelWidth,2)
				+ pow((firstPoint.y - point3D.y) * voxelHeight,2)
				+ pow((firstPoint.z - point3D.z) * voxelDepth,2));
			double distance2 = sqrt( pow((nextPoint.x - point3D.x) * voxelWidth,2)
				+ pow((nextPoint.y - point3D.y) * voxelHeight,2)
				+ pow((nextPoint.z - point3D.z) * voxelDepth,2));
			if ((distance1 <= distance) && (distance2 <= distance)) {
				int index = [pointArray indexOfObject:point3D];
				if (index < [originalPoints count]);
					[nearbyPoints addObject:[originalPoints objectAtIndex:index]];
			}
		}
		
		NSLog(@"nearby points: %d", [nearbyPoints count]);
		double neighborsCount = (double)[nearbyPoints count];
		double xPos, yPos, zPos;
		for (OSIPoint3D *point3D in nearbyPoints) {
			xPos += point3D.x;
			yPos += point3D.y;
			zPos += point3D.z;
			
		}
		
		xPos /= neighborsCount;
		yPos /= neighborsCount;
		zPos /= neighborsCount;
		
		[centerlinePoints addObject:[OSIPoint3D pointWithX: xPos y:yPos z:zPos value:nil]];		
		NSLog(@"add Centerline point: %@", [centerlinePoints lastObject]);
	}
	
	NSLog(@"centerline Points: %d", [centerlinePoints count]);
	
	decimate->Delete();

	//return connectedPoints;	
	//return arrangedPoints;
	return centerlinePoints;	
	

}

- (NSMutableSet *)connectedPointsForPoint:(vtkIdType)pt fromPolyData:(vtkPolyData *)data{
	NSMutableSet *ptSet = [NSMutableSet set];
	vtkIdType ncells;
	vtkIdList *cellIds = vtkIdList::New();

	// All cells for Point and number of cells
	data->GetPointCells	(pt, cellIds);	
	ncells = cellIds->GetNumberOfIds();
	// loop through the cells
	for (int j = 0;  j < ncells; j++) {
		vtkIdType numPoints;
		vtkIdType *cellPoints ;
		vtkIdType cellId = cellIds->GetId(j);
		//get all points for the cell
		data->GetCellPoints(cellId, numPoints, cellPoints);				
		// points may be duplicate
		for (int k = 0; k < numPoints; k++) {	
			NSNumber *number = [NSNumber numberWithInt:cellPoints[k]];
			[ptSet addObject:number];
		 }
	}
	cellIds -> Delete();
	//NSLog(@"number in Set: %d\n%@", [ptSet count], ptSet);
	return ptSet;
}




@end
