# Sw4lite HIP version

The HIP version of Sw4lite, intended to run in AMD GPUs, is based off the 
CUDA version in the master branch of the Sw4lite repository at
git@github.com:geodynamics/sw4lite.git. AMD is in the process of open-sourcing
the hip branch. Pending legal review, AMD provides the hip branch as a
tarball to the DoE under NDA.

## Prerequisites

The HIP version of Sw4lite assumes a ROCm 2.6 installation, and depends
on MPI and lapack libraries.

## Building

Check the `MPIPATH` near the top of `Makefile.hip`, and edit as necessary.
Next, issue `make -f Makefile.hip -j`.

Note: the build process involves running `hipify-perl` on CUDA files. This
script issues warnings whenever it encounters symbols containing the
substring `cuda` that is doesn't know about. Sw4lite has a number of 
user-defined functions with `cuda` in the name. Obviously, these need not
be hipified, and the `hipify-perl` warnings for these functions can be 
ignored:

```
  warning: src/EW_cuda.C:#902 :       CheckCudaCall(hipGetLastError(), "BufferToHaloKernel<<<,>>>(...)", __FILE__, __LINE__);
```

## Running

We've tested the HIP version only on the provided pointsource input, running
with a single rank:

```bash
./optimize_hip/sw4lite tests/pointsource/pointsource.in
```

It should report the errors as specified in the [README.md file](README.md):
```
Errors at time 0.6 Linf = 0.569416 L2 = 0.0245361 norm of solution = 3.7439
```

## Changes w.r.t. the CUDA version

### Main change: work-around for function pointers.

The CUDA version uses `__device__` function pointers to select specific
versions of time functions and their derivatives at run time. While
AMD GPU hardware supports function calls, the HIP compiler currently does
not support device function calls; the compiler inlines all device function
calls in source code, but this is not possible when device function pointers
are selected at runtime.

As a temporary work-around, we modified the CUDA code in the hip branch, and
replaced every call through a function pointer with a switch statement, where
the chosen case depends on a variable `mTimeDependence` that is set at runtime.

The reason for modifying the CUDA code prior to hipifying, rather than 
hipifying first and then modifying the hipified code, is that this allows us
to assess the performance impact of replacing function pointers by (large)
switch statements on NVIDIA hardware. To run the CUDA version unmodified, 
using function pointers, build using `Makefile.cuda` as usual. To run the
CUDA version with the function pointer work-around, add 
`-DUSE_FUNCTION_POINTER_WORKAROUND` to the compilation flags. We have observed
a performance drop of up to 20%, depending on the order of the cases in the
switch statements.

### Minor changes

The remaining changes to the CUDA code required to get the hipified code
to compile and to run correctly are relatively minor:

* Some variables in device code were used uninitialized. Apparently, this 
  bug did not cause issues in the CUDA version, but it lead to incorrect 
  and inconsistent results in the HIP version.
* The clang-based HIP compiler complained about some instances of `NULL`,
  and we replaced those by `nullptr`.
