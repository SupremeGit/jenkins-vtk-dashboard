#!/bin/bash

#The problem which I was trying to solve by isolating this failing test, turned out to be caused by DPMS turning monitor off,
#and nvidia drivers then "optimise" away all the drawing operations. Nothing is actually drawn. So then when the drawn image is 
#captured, it's blank, & does not match reference image, so tests fail.

#MESA WORKS ON VNC WHEN THIS IS EXPORTED!! 
#with the exception of about 102 tests, which require floating point support, which isn't supported by the mesa being used by vnc
#export MESA_GL_VERSION_OVERRIDE=3.2

VTK_BUILD_DIR="/data-ssd/data/development/src/vtk/build/jenkins/dashboard/nightly/1/vtk-build"

export XAUTHORITY=/run/user/1000/gdm/Xauthority
export DISPLAY=:0.0

#export XAUTHORITY=/home/jss/.Xauthority
#export DISPLAY=:1.0
#export DISPLAY=:2.0
#export DISPLAY=:14

#xhost +

"${VTK_BUILD_DIR}/bin/vtkChartsCoreCxxTests" "TestMultipleRenderers" "-E" "25" "-D" "${VTK_BUILD_DIR}/ExternalData/Testing" "-T" "${VTK_BUILD_DIR}/Testing/Temporary" "-V" "${VTK_BUILD_DIR}/ExternalData/Charts/Core/Testing/Data/Baseline/TestMultipleRenderers.png"

#glxgears

#env > ~/vtk-test.env.txt
