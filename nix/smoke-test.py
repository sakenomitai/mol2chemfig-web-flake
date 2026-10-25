"""Render a few molecules through the Flask routes and check that PDFs come out.

usage: python smoke-test.py <share/mol2chemfig-web directory>
"""
import base64
import sys

sys.path.insert(0, sys.argv[1])

from app import app

client = app.test_client()
PDF_PREFIX = "data:application/pdf;base64,"


def get_json(path, **query):
    response = client.get(path, query_string=query)
    assert response.status_code == 200, (path, response.status_code)
    return response.get_json()


def assert_pdf(link, what):
    assert isinstance(link, str) and link.startswith(PDF_PREFIX), (what, link)
    assert base64.b64decode(link[len(PDF_PREFIX):]).startswith(b"%PDF"), what


assert client.get("/mol_2_chemfig").status_code == 200

# SMILES input (caffeine), then re-render with other options
result = get_json("/mol_2_chemfig/smiles_to_chemfig",
                  smiles_mol="CN1C=NC2=C1C(=O)N(C(=O)N2C)C",
                  check="-w", angle="0.0", hydrogens="keep")
assert r"\chemfig" in result["chem_fig"], result
assert_pdf(result["pdf_link"], "caffeine")

result = get_json("/mol_2_chemfig/update", check="-w,-c,-f", angle="30", hydrogens="add")
assert_pdf(result["pdf_link"], "caffeine with options")

# aromatic circles
result = get_json("/mol_2_chemfig/smiles_to_chemfig",
                  smiles_mol="c1ccc2ccccc2c1", check="-o", angle="0.0", hydrogens="keep")
assert r"\mcfcringle" in result["chem_fig"], result
assert_pdf(result["pdf_link"], "naphthalene")

# editing the chemfig code directly
result = get_json("/mol_2_chemfig/smiles_to_chemfig",
                  smiles_mol="OC1=CC=CC=C1", check="", angle="0.0", hydrogens="keep")
result = get_json("/mol_2_chemfig/update_chemfig", smiles_mol=result["chem_fig"])
assert_pdf(result["pdf_link"], "edited chemfig code")

# a molfile, long enough to go through MOL2CHEMFIG_DATA_DIR
with open(sys.argv[1] + "/static/ChemDoodle/data/molecules/aspirin.mol") as f:
    molfile = f.read()
result = get_json("/mol_2_chemfig/smiles_to_chemfig",
                  smiles_mol=molfile, check="-w", angle="0.0", hydrogens="keep")
assert_pdf(result["pdf_link"], "molfile")

# bad input is reported, not raised
result = get_json("/mol_2_chemfig/smiles_to_chemfig",
                  smiles_mol="foo(", check="-w", angle="0.0", hydrogens="keep")
assert result["chem_fig"] is None, result

print("smoke test passed")
