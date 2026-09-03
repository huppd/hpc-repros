# Builds the reproducer against whatever MPI Fortran wrapper ($FC) is
# currently active in the environment (e.g. a uenv view, or a manually
# activated /mch-environment/vN -- see README.md).
#
#   make FC=mpif90
#
# For building and submitting BOTH the uenv and the /mch-environment/v8
# variants in one go, use ./run_both.sh instead.

FC ?= mpif90
TARGET := hello

all: $(TARGET)

$(TARGET): hello.f90
	$(FC) -o $(TARGET) hello.f90

clean:
	rm -f $(TARGET) hello_uenv hello_v8 *.o *.mod

.PHONY: all clean
