"""Pytest collection scope for the OMNIVEST backend suites.

`test_api.py` is an **end-to-end smoke test that requires a running server**; its
own module docstring documents the two-terminal flow:

    cd backend && ./.venv/bin/python run.py            # terminal 1
    ./.venv/bin/python -m app.tests.test_api           # terminal 2

It is not a unit test. Collecting it under a bare `pytest app/tests` produced two
red results that meant nothing except "no server is listening", which trains
people to ignore red. Exclude it here and keep its real entry points:
`make test-api`, or `python -m app.tests.test_api` against a booted server.

Everything else in `app/tests/` runs with no server and must stay collected.
"""

collect_ignore = ["test_api.py"]
