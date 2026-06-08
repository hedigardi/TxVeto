# TxVeto 0.1.x Release Checklist

## Pre-release

- Update `pyproject.toml` version.
- Update `CHANGELOG.md` with release date and notes.
- Run tests:

```bash
python -m pytest tests/test_web_demo.py tests/test_policy_and_demo.py tests/test_mcp_server.py tests/test_runaway_agent.py
```

## Build

```bash
python -m pip install --upgrade build twine
python -m build
python -m twine check dist/*
```

## Publish to TestPyPI (recommended)

```bash
python -m twine upload --repository testpypi dist/*
```

## Publish to PyPI

```bash
python -m twine upload dist/*
```

## Post-release verification

```bash
python -m pip install txveto
python -m txveto.demo --mode both
```
