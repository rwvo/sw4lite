CXX = HIPCC_VERBOSE=1 hipcc

MPIPATH = /usr/lib/x86_64-linux-gnu/openmpi
MPIINC = $(MPIPATH)/include
MPILIB = $(MPIPATH)/lib

builddir = optimize_hip

CXXFLAGS = -g -Ofast -Ihipsrc -DSW4_CROUTINES -DSW4_CUDA -I$(MPIINC)
CXXFLAGS += -Ihipsrc/double
CXXFLAGS += -DUSE_FUNCTION_PTR_WORKAROUND

##############################################################################################
# OBJ: copied from Makefile.cuda
OBJ  = main.o EW.o Source.o rhs4sg.o rhs4sg_rev.o SuperGrid.o GridPointSource.o time_functions_cu.o ew-cfromfort.o EW_cuda.o Sarray.o device-routines.o EWCuda.o CheckPoint.o Parallel_IO.o EW-dg.o MaterialData.o MaterialBlock.o Polynomial.o SecondOrderSection.o TimeSeries.o sacsubc.o curvilinear-c.o rhs4sgcurv.o rhs4sgcurv_rev.o


HIP_SOURCES := $(patsubst %.o,hipsrc/%.C,$(OBJ))
HIP_HEADERS := $(patsubst src/%,hipsrc/%,$(wildcard src/*.h))
HIP_HEADERS += $(patsubst src/%,hipsrc/%,$(wildcard src/double/*.h))
HIP_HEADERS += $(patsubst src/%,hipsrc/%,$(wildcard src/float/*.h))
HIP_OBJ := $(addprefix $(builddir)/,$(OBJ))

$(builddir)/sw4lite: hipify $(builddir) $(HIP_OBJ)
	$(CXX) -L$(MPILIB) $(OMPOPT) -Xlinker "-rpath=$(MPILIB)" -o $@ $(HIP_OBJ) -lmpi -llapack

$(builddir):
	mkdir -p $(builddir)

$(builddir)/%.o:hipsrc/%.C
	$(CXX) $(CXXFLAGS) -c $< -o $@

hipify: hipsrc $(HIP_SOURCES) $(HIP_HEADERS)

hipsrc:
	mkdir -p hipsrc/float hipsrc/double

# Handle Sarray.C separately; need to deal with missing translation in hipify-perl
# Once hipify-perl is updated/fixed, this special case can be removed
# Pull request for the fix was merged 2019-08-08, should be in ROCm 2.7 or 2.8
hipsrc/Sarray.C: src/Sarray.C | hipsrc
	hipify-perl $< > $@
	sed -i -e 's/cudaHostRegisterDefault/hipHostRegisterDefault/g' $@

# Handle sw4.h separately: add '#include <hip/hip_runtime.h>'
hipsrc/float/sw4.h: src/float/sw4.h | hipsrc
	hipify-perl $< > $@
	sed -i -e '/#define SW4_H/a\' -e '#include <hip/hip_runtime.h>' $@

hipsrc/double/sw4.h: src/double/sw4.h | hipsrc
	hipify-perl $< > $@
	sed -i -e '/#define SW4_H/a\' -e '#include <hip/hip_runtime.h>' $@

hipsrc/%: src/% | hipsrc
	hipify-perl $< > $@

clean:
	rm -rf hipsrc $(builddir)

