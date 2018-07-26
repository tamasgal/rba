# RainbowAlga

RainbowAlga is an event dispatcher for the online event display **aa3d**.

## Installation

The following steps are required to get RainbowAlga up and running:

    git clone http://git.km3net.de/common/rba.git
    cd rba/www/aa3d
    python brew.py
    cd ../../..
    pip install .

This will generate the JavaScript files from the coffee files (you need
coffee for this) and install a ``rainbowalga`` command line utility.

## Usage

Run the command ``rainbowalga`` from everywhere and point your browser to
<http://127.0.0.1:8088>.


## Development Installation

See the steps above, but do ``pip install -e .`` instead. This will just
link the directory to the Python site-packages folder.
