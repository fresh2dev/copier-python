import sys

import yapx

from . import __version__


def setup() -> None:
    pass


def main() -> None:
    yapx.run(
        setup,
        prog_version=__version__,
        args=sys.argv[1:],
    )


if __name__ == "__main__":
    main()
