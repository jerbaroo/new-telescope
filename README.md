<div align="center">

# Telescope
[![Build Status](https://img.shields.io/github/workflow/status/jerbaroo/telescope/Test)](https://github.com/jerbaroo/telescope/actions?query=workflow%3ATest)

</div>

### Table of Contents
- [Introduction](#introduction)
- [Getting Started](#getting-started)
- [Application Architecture](#application-architecture)
- [Another Web Framework?](#another-web-framework)
- [Technical Details](#technical-details)
- [Contributing](#contributing)
- [Name](#name)

# Introduction
*Minimum viable product. Not production ready.*

Telescope is a Haskell framework for building reactive web apps, fast. Telescope
abstracts away common tasks you undertake when developing a web app, **allowing
you to focus on your business logic** and **reducing the time you need to build
your app**.

An application built with Telescope is..
- **Reactive:** don't worry about keeping client-side and server-side data in
  sync, your frontend can automatically react to changes in your database and
  your database can be updated seamlessly by your frontend!
- **Robust:** writing the strongly-typed language Haskell across the stack
  prevents server/client protocol mismatches and other run-time errors, allowing
  you to move fast and not break things.
- **Minimal:** Telescope can setup a database and server for you and also manage
  communication between client and server, so you can focus on the parts of your
  application that really matter.

What are Telescope's limitations?
- Does not provide a full-featured database query language.
- Only supports a limited subset of Haskell data types.

Telescope is particularly well-suited for applications where events are pushed
by the server e.g. notifications and dashboards. Telescope also handles forms
and input-validation very well. On the flip-side, applications with heavy
client-side computation such as animations are not well-suited for Telescope.

## Getting Started
Building a reactive web app with Telescope looks something like this:

**1.** Declare the data types used in your application.

``` haskell
data ToDoList = ToDoList
  { name  :: Text
  , items :: [Text]
  } deriving (Generic, Show)

instance PrimaryKey ToDoList Text where
  primaryKey = name
```

**2.** Populate your database with some data.

``` haskell
T.set $ ToDoList "pancakes" ["eggs", "milk", "flour"]
```

**3.** Start the Telescope server.

``` haskell
Server.run port
```

**4.** Write the frontend of your reactive web app with
[Reflex-DOM](https://reflex-frp.org/)!

``` haskell
-- NOTE: work in progress.
main = mainWidget $ el "div" $ do
  el "h3" $ text "View a todo list"
  inputDyn <- textInput def
  list <- flip T.viewKRx
    (unpack <$> inputDyn ^. textInput_value)
    (const TodoList{} <$> (inputDyn ^. textInput_value))
  dynText $ fmap (pack . show) people
```

**5.** Open the app in two browser tabs. Edit one to-do-list and watch the other
one react!

A full tutorial and demo application are available TODO.
<!-- TODO: links to reflex-platform and other doc in demo/README.md -->

## Application Architecture
<!-- Core is the Telescope interface, available client & server-side. -->
The most important component of Telescope from an application developer's
perspective is the Telescope interface, a set of functions that allow you to
read/write datatypes from/to a data source. This interface is available both
server-side and client-side. The diagram below shows one possible setup of a
Telescope application, each telescope icon represents usage of the Telescope
interface.

<!-- Bottom row. -->
The bottom row of the diagram represents a developer interacting with a database
on their own machine. More specifically the developer has opened a REPL and is
using the Telescope interface to interact with the local database.

<!-- Top row, server is a proxy. -->
The top row of the diagram shows two uses of the Telescope interface, one by a
server, and one by a web client. The server is interacting with the database via
the Telescope interface and acts as a proxy to the database for any web clients.
The web client is communicating with the server via the Telescope interface, but
since the server is only acting as a proxy the client is really interacting with
the database.

<div align="center">
  <img src="diagram/diagram.png" />
</div>

There are a number of important points about the Telescope interface which we
will now discuss in turn, referring back to the architecture diagram above.
- Reactive variants of Telescope functions.
- Multiple instances of the Telescope interface.
- The Telescope interface is data source agnostic.
- Data is uniquely determined by type and primary key.
<!-- TODO: finish discussion about these points. -->
<!-- TODO: outline data flow, top row subscribes and reacts to data. -->

## Another Web Framework?
<!-- Many existing frameworks, pros and cons. -->
There are many different web frameworks out there, and they all have pros and
cons. They pretty much all allow you to write reuseable components. Some can
ship a small file to the client, some allow you to write your server-side and
client-side code in the same language, some can pre-render server-side for a
speedy TTI (time to interactive).

<!-- Reactive frontend is popular. -->
One idea that has become fairly popular in recent years is that of a reactive
frontend. Whereby the frontend is written as a function of the current state,
and whenever the state changes, the frontend "reacts" to the change and updates
itself.

<!-- Network is boundary of reactivity. -->
Implementations of reactive frontends vary, however in the vast majority of
cases one significant limitation is that the frontend only reacts to client-side
changes in data. At this network boundary the developer still has to manage
communication with a server.

<!-- Liberated of where/when. -->
The primary motivation behind creating Telescope is that a developer should be
able to **write a reactive frontend as a function of data in their one true data
source**. Telescope solves this by providing a direct Reflex-DOM <-> database
link. Even better, the Telescope interface is not specific to Reflex-DOM or the
database. You could write an instance to use in e.g. a `reflex-vty` application,
or to communicate with a different server or database.

## Technical Details 
<!-- Reactive interface to data, data location is a parameter. -->
<!-- TODO: Rewrite paragraph. -->
So Telescope is a web framework? More generally Telescope provides a reactive
interface (the `Telescope` typeclass) to read/write datatypes from/to a data
source. The data source's location (e.g. filepath or URL) is a parameter of the
interface, allowing you to use the same interface to read/write data regardless
of where that data is stored. Even better, you can use the Telescope interface
both server-side and client-side. The use of the term "reactive" in "reactive
interface" refers to the fact that clients can subscribe to changes in data,
reacting to any changes.

<!-- Various packages. -->
The `telescope` package provides the Telescope interface without any instances.
The `telescope-ds-file` package provides an instance of the interface, that
stores data in local files. The `telescope-ds-reflex-dom` package provides an
instance of the interface to be used in a [Reflex-DOM](https://reflex-frp.org/)
web app, it talks to a server to read/write data. The `telescope-server` package
provides a [Servant](https://www.servant.dev/) server that serves data via a
provided instance of the Telescope interface e.g. from `telescope-ds-file`.

<!-- Generic programming. -->
The Telescope interface provides functions that operate on datatypes which are
instances of the `Entity` typeclass. You only need to define a primary key for
your datatype and then the `Entity` instance can be derived for your datatype
via `Generics`. Generic programming allows conversion of your datatype to/from
storable representation. The following diagram shows this conversion.

``` haskell
-- Example of a datatype to be stored.
data Person { name :: Text, age  :: Int } deriving Generic
instance PrimaryKey Person where primaryKey = name
  
-- Diagram showing conversion to/from storable representation.
Person "john" 70     <--->     "Person"
                               | ID     | "name" | "age" |
                               | "john" | "john" | 70    |
```

<!-- TODO: example that results in two rows. -->

## Contributing
These instruction will help you get started if you want to contribute to this
project. Install [Nix](https://nixos.org/download.html) the package manager, and
[Cachix](https://docs.cachix.org/) to make use of our binary cache. Then clone
this repository (with submodules) and change in to the `telescope` directory.
Now run the build step, using Cachix to download pre-built binaries:

``` bash
curl -L https://nixos.org/nix/install | sh
nix-env -iA cachix -f https://cachix.org/api/v1/install
git clone --recurse-submodules https://github.com/jerbaroo/telescope
cd telescope
./scripts/cachix/use.sh
```

Development commands for the Telescope framework:

``` bash
# Type-check (with GHCID) the package passed as first argument.
./scripts/check.sh telescope
# Run all test suites with Cabal.
./scripts/test/suite.sh
# Build all packages with Nix (GHC & GHCJS) and run test suites.
./scripts/test/full.sh
# Start a Hoogle server (optional port argument, default=5000).
./scripts/hoogle.sh 5000
```

Development commands for the "testing" app:

``` bash
# Run the testing-backend server, server restarts on file change.
./scripts/run/dev.sh testing-backend
# Run the testing-frontend server, server restarts on file change.
./scripts/run/dev.sh testing-frontend
# Enter a REPL for interacting with the testing's database. TODO: FIX.
./scripts/repl.sh testing-backend
```

Production commands for the "testing" app:

``` bash 
# Build the testing-backend server.
./scripts/build/prod.sh testing-backend
# Generate the testing-frontend static files.
./scripts/build/prod.sh testing-frontend
# Run the testing-backend server.
./scripts/run/prod.sh testing-backend
```

## Name
The `telescope` package provides an interface to read/write remote data i.e.
data stored in a database or data accessed over the network. This interface is
"lens-like" i.e. the functions are similar to the functions `view`, `set` etc.
that you may know from the `lens` library. So if you squint your eyes a little
you could say this library provides a lens to look at remote data... like a
telescope.
