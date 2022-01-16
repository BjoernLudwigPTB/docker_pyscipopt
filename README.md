# docker_pyscipopt

This work is heavily based on the preparations that were made by Aleksey Piskun in his
repository [docker-scip](https://github.com/viktorsapozhok/docker-scip). We thank
Aleksey for his thorough preparation.

## Why this fork?

We wanted to work on the most recent version of PySCIPOpt which is based on the most
recent (beta) version of the SCIP Optimization Suite at the time of writing. Besides we
chose few optimizations for some of the design decisions Aleksey has made for his image.
Additionally we thought, that a name that emphasizes the use of PYSCIPOPT as the API is
more suitable.

## Content of docker_pyscipopt

Building a Docker container with the SCIP Optimization Suite (version 8.0.0) + Solving
optimization (0-1 knapsack problem) with PySCIPOpt (version 4.0.0) inside the container.

## Why to choose SCIP

SCIP is currently one of the fastest non-commercial solvers for mixed integer 
programming (MIP) and mixed integer nonlinear programming (MINLP). It's regularly
updated releasing a new version several times a year. In addition, an easy-to-use
Python API to the SCIP Optimization Suite is available [PySCIPOpt
](https://github.com/scipopt/PySCIPOpt/). 

## How to build image

Before we can start a container, we first have to build an image for it, which
serves as a template for every instance. To install the SCIP Optimization Suite
into that image, we need to download the according version, currently it's
**8.0.0.**. SCIP is distributed under the Academic License, and is downloadable from
the [official website](https://www.scipopt.org/index.php#download). Due the license
terms we cannot distribute the software itself alongside this Docker code.

Note, that we need to download the Debian .deb installer (careful: there is an Ubuntu
.deb as well, which will most likely not work). We download the file into the root
directory (where the Dockerfile and this README is located).

Then we build a Docker image via the following command from the root directory:

```shell
$ docker-compose build
Sending build context to Docker daemon  23.66MB
Step 1/12 : FROM python:3.10-slim
 ---> 58d8fd9767c5
Step 2/12 : RUN apt-get update &&     DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends     gcc     g++     libcliquer1     gfortran     libgsl25     liblapack3     libopenblas-dev     libtbb2
 ---> Using cache
 ---> 53b99beda737
Step 3/12 : COPY SCIPOptSuite-8.0.0-Linux-debian.deb /srv/pyscipopt/
 ---> Using cache
 ---> 52d518cd77a7
Step 4/12 : WORKDIR /srv/pyscipopt/
 ---> Using cache
 ---> 98f59f5f71ff
Step 5/12 : RUN dpkg -i SCIPOptSuite-8.0.0-Linux-debian.deb &&     rm SCIPOptSuite-8.0.0-Linux-debian.deb
 ---> Using cache
 ---> 02e3310fb697
Step 6/12 : RUN groupadd --gid 1000 user     && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash user     && chown -R "1000:1000" /home/user
 ---> Using cache
 ---> 78ea15aacd46
Step 7/12 : COPY requirements.txt /srv/pyscipopt/
 ---> Using cache
 ---> 2d45e20a3dff
Step 8/12 : RUN pip install --upgrade pip pip-tools && python -m piptools sync
 ---> Using cache
 ---> 3e8367d58834
Step 9/12 : USER user
 ---> Using cache
 ---> 3609f1b511d3
Step 10/12 : WORKDIR /home/user
 ---> Using cache
 ---> 119cb1a5af0a
Step 11/12 : VOLUME /home/user
 ---> Using cache
 ---> 85ebc6cd634e
Step 12/12 : ENTRYPOINT ["python"]
 ---> Using cache
 ---> f52d4ea18334
Successfully built f52d4ea18334
Successfully tagged pyscipopt:4.0.0
```

This will tag the built image with "4.0.0" for the version of PySCIPOpt installed and
tells Docker to use the recipe from the Dockerfile in the current location for the
build.

When the build process is over, you will find the new image via:

```shell
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
pyscipopt           4.0.0               78791bbde634        14 hours ago        599MB
```

## Packing knapsack

To demonstrate how to use PySCIPOpt, we show how to solve a small-scale 
[knapsack problem](https://en.wikipedia.org/wiki/Knapsack_problem) for the case of
multiple knapsacks.

Let's assume, that we have a collection of items with different weights and values, and
we want to pack a subset of items into five knapsacks (bins), where each knapsack has a
maximum capacity 100, so the total packed value is a maximum.

Define a simple container class to store item parameters and initialize 15 items.

```python
class Item:
    def __init__(self, index, weight, value):
        self.index = index
        self.weight = weight
        self.value = value

items = [
    Item(1, 48, 10), Item(2, 30, 30), Item(3, 42, 25), Item(4, 36, 50), Item(5, 36, 35), 
    Item(6, 48, 30), Item(7, 42, 15), Item(8, 42, 40), Item(9, 36, 30), Item(10, 24, 35), 
    Item(11, 30, 45), Item(12, 30, 10), Item(13, 42, 20), Item(14, 36, 30), Item(15, 36, 25)
]
```

Introduce bins (knapsacks) in the similar fashion.

```python
class Bin:
    def __init__(self, index, capacity):
        self.index = index
        self.capacity = capacity

bins = [Bin(1, 100), Bin(2, 100), Bin(3, 100), Bin(4, 100), Bin(5, 100)]
```

As a next step, we create a solver instance.

```python
from pyscipopt import Model, quicksum

model = Model()
```

We introduce the binary variables `x[i, j]` indicating that item `i` is packed into bin `j`.

```python
x = dict()
for _item in items:
    for _bin in bins:
        x[_item.index, _bin.index] = model.addVar(vtype="B")
```

Now we add the constraints which prevent the situations when the same item is packed
into multiple bins. It says that each item can be placed in at most one bin.

```python
for _item in items:
    model.addCons(quicksum(x[_item.index, _bin.index] for _bin in bins) <= 1)
```

The following constraints require that the total weight packed in each knapsack don't
exceed its maximum capacity.

```python
for _bin in bins:
    model.addCons(
        quicksum(
            _item.weight * x[_item.index, _bin.index] for _item in items
        ) <= _bin.capacity)
```

Finally, we define an objective function as a total value of the packed items and run
the optimization.

```python
model.setObjective(
    quicksum(
        _item.value * x[_item.index, _bin.index]
        for _item in items for _bin in bins
    ), 
    sense="maximize")

model.optimize()
```

See script `knapsack.py` for more details.

## Running SCIP solver inside Docker

To run the script we start a Docker container from our image, include the current
working directory's content into the container and hand over the name of the script.
To simplify making the script accessible from inside the container, we use
`docker-compose` and its `run` command with the `--rm` option to delete the container
immediatly after execution of the script:

```shell
$ docker-compose run --rm pyscipopt knapsack.py
...
Bin 1
Item 6: weight 48, value 30
Item 13: weight 42, value 20
Packed bin weight: 90
Packed bin value : 50

Bin 2
Item 3: weight 42, value 25
Item 8: weight 42, value 40
Packed bin weight: 84
Packed bin value : 65

Bin 3
Item 4: weight 36, value 50
Item 5: weight 36, value 35
Item 10: weight 24, value 35
Packed bin weight: 96
Packed bin value : 120

Bin 4
Item 2: weight 30, value 30
Item 11: weight 30, value 45
Item 14: weight 36, value 30
Packed bin weight: 96
Packed bin value : 105

Bin 5
Item 9: weight 36, value 30
Item 15: weight 36, value 25
Packed bin weight: 72
Packed bin value : 55

Total packed value: 395.0
```

Read Aleksey's [tutorial][1] for more.

[1]: https://viktorsapozhok.github.io/docker-scip-pyscipopt/ "How to insPySCIPOpt in a docker container"
