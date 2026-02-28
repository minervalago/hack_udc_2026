#!/usr/bin/env python3
"""Generador de datos sintéticos para Beca MEC - HackUDC 2026"""

import csv
import random
import os

random.seed(42)

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data")

# Umbrales de renta MEC por número de miembros de la unidad familiar
UMBRALES = {
    1: (9315,  14818),
    2: (13971, 25293),
    3: (19000, 34332),
    4: (23286, 40773),
    5: (27012, 42743),
}

NOMBRES = [
    "María", "José", "Carmen", "Antonio", "Ana", "Manuel", "Isabel", "Francisco",
    "Laura", "David", "Marta", "Javier", "Sara", "Carlos", "Elena", "Miguel",
    "Paula", "Alejandro", "Lucía", "Rafael", "Andrea", "Daniel", "Cristina",
    "Pedro", "Sofía", "Sergio", "Nuria", "Álvaro", "Patricia", "Roberto",
    "Raquel", "Andrés", "Beatriz", "Pablo", "Silvia", "Jorge", "Rocío",
    "Adrián", "Marina", "Rubén", "Inés",
]

APELLIDOS = [
    "García", "Martínez", "López", "Sánchez", "González", "Pérez", "Rodríguez",
    "Fernández", "Torres", "Ramírez", "Flores", "Díaz", "Reyes", "Morales",
    "Jiménez", "Ruiz", "Hernández", "Álvarez", "Romero", "Alonso", "Navarro",
    "Molina", "Moreno", "Ortega", "Delgado", "Castro", "Ortiz", "Rubio",
    "Marín", "Sanz", "Núñez", "Iglesias", "Medina", "Garrido", "Santos",
    "Castillo", "Gil", "Serrano", "Blanco", "Muñoz",
]

MUNICIPIOS = [
    ("A Coruña", "A Coruña"), ("Santiago de Compostela", "A Coruña"),
    ("Ferrol", "A Coruña"), ("Lugo", "Lugo"), ("Ourense", "Ourense"),
    ("Vigo", "Pontevedra"), ("Pontevedra", "Pontevedra"),
    ("Madrid", "Madrid"), ("Barcelona", "Barcelona"), ("Valencia", "Valencia"),
    ("Sevilla", "Sevilla"), ("Zaragoza", "Zaragoza"), ("Málaga", "Málaga"),
    ("Murcia", "Murcia"), ("Bilbao", "Vizcaya"), ("Alicante", "Alicante"),
    ("Córdoba", "Córdoba"), ("Valladolid", "Valladolid"), ("Gijón", "Asturias"),
    ("Granada", "Granada"), ("Vitoria", "Álava"), ("Oviedo", "Asturias"),
    ("Pamplona", "Navarra"), ("San Sebastián", "Guipúzcoa"),
    ("Burgos", "Burgos"), ("Salamanca", "Salamanca"), ("Almería", "Almería"),
    ("Castellón", "Castellón"), ("Jerez de la Frontera", "Cádiz"),
    ("Alcalá de Henares", "Madrid"),
]

CALLES = [
    "Calle Mayor", "Avenida de la Constitución", "Calle Real", "Paseo del Prado",
    "Gran Vía", "Avenida de España", "Calle Cervantes", "Calle Colón",
    "Avenida de Galicia", "Calle San Juan", "Rúa Nova", "Calle del Sol",
    "Avenida de Portugal", "Rúa do Franco", "Calle Ancha", "Calle Independencia",
]

CIUDADES_ESTUDIO = [
    "A Coruña", "Ferrol", "Santiago de Compostela", "Lugo", "Ourense",
    "Vigo", "Pontevedra", "Madrid", "Barcelona", "Valencia",
    "Salamanca", "Granada", "Sevilla", "Bilbao", "Oviedo", "Valladolid",
]


def generate_nif() -> str:
    number = random.randint(10000000, 99999999)
    letters = "TRWAGMYFPDXBNJZSQVHLCKE"
    return f"{number}{letters[number % 23]}"


def generate_nombre() -> str:
    return f"{random.choice(NOMBRES)} {random.choice(APELLIDOS)} {random.choice(APELLIDOS)}"


def generate_domicilio():
    municipio, provincia = random.choice(MUNICIPIOS)
    calle = random.choice(CALLES)
    numero = random.randint(1, 120)
    piso = random.choice(["Bajo", "1º A", "1º B", "2º A", "2º B", "3º C", "4º A"])
    return f"{calle} {numero}, {piso}", municipio, provincia


def build_record(idx, num_miembros, renta, nacionalidad_esp,
                 repite, discapacidad, orfandad, familia_numerosa, reside_fuera):
    domicilio, municipio, provincia = generate_domicilio()
    ciudad_estudio = random.choice(CIUDADES_ESTUDIO) if reside_fuera else municipio
    return {
        "id_solicitud":                  f"SOL-MEC-{idx:03d}",
        "nif_solicitante":               generate_nif(),
        "nombre_solicitante":            generate_nombre(),
        "domicilio_familiar":            domicilio,
        "municipio_domicilio":           municipio,
        "provincia_domicilio":           provincia,
        "reside_fuera_domicilio":        reside_fuera,
        "ciudad_residencia_curso":       ciudad_estudio,
        "renta_anual_familiar":          round(renta, 2),
        "num_miembros_unidad_familiar":  num_miembros,
        "discapacidad":                  discapacidad,
        "orfandad":                      orfandad,
        "familia_numerosa":              familia_numerosa,
        "nacionalidad_espanola":         nacionalidad_esp,
        "repite_curso":                  repite,
    }


records = []
idx = 1

# --- 5 descartados: nacionalidad no española ---
for _ in range(5):
    nm = random.randint(1, 5)
    u1, u2 = UMBRALES[nm]
    renta = random.uniform(u1 * 0.4, u2 * 0.9)
    records.append(build_record(
        idx, nm, renta,
        nacionalidad_esp=False, repite=False,
        discapacidad=random.random() < 0.10,
        orfandad=random.random() < 0.05,
        familia_numerosa=random.random() < 0.20,
        reside_fuera=random.random() < 0.50,
    ))
    idx += 1

# --- 8 descartados: repite curso ---
for _ in range(8):
    nm = random.randint(1, 5)
    u1, u2 = UMBRALES[nm]
    renta = random.uniform(u1 * 0.3, u2 * 0.85)
    records.append(build_record(
        idx, nm, renta,
        nacionalidad_esp=True, repite=True,
        discapacidad=random.random() < 0.10,
        orfandad=random.random() < 0.05,
        familia_numerosa=random.random() < 0.20,
        reside_fuera=random.random() < 0.50,
    ))
    idx += 1

# --- 12 descartados: renta supera umbral 2 ---
for _ in range(12):
    nm = random.randint(1, 5)
    _, u2 = UMBRALES[nm]
    renta = random.uniform(u2 * 1.05, u2 * 1.80)
    records.append(build_record(
        idx, nm, renta,
        nacionalidad_esp=True, repite=False,
        discapacidad=random.random() < 0.05,
        orfandad=random.random() < 0.03,
        familia_numerosa=random.random() < 0.20,
        reside_fuera=random.random() < 0.40,
    ))
    idx += 1

# --- 75 elegibles ---
for _ in range(75):
    nm = random.randint(1, 5)
    u1, u2 = UMBRALES[nm]
    # 35% con renta por debajo del umbral 1 (candidatos fuertes)
    # 65% entre umbral 1 y umbral 2
    if random.random() < 0.35:
        renta = random.uniform(u1 * 0.10, u1 * 0.99)
    else:
        renta = random.uniform(u1 * 1.01, u2 * 0.99)

    discapacidad   = random.random() < 0.12
    orfandad       = random.random() < 0.07
    # familia_numerosa solo aplica si hay suficientes miembros
    familia_numerosa = (nm >= 3) and (random.random() < 0.40)
    reside_fuera   = random.random() < 0.55

    records.append(build_record(
        idx, nm, renta,
        nacionalidad_esp=True, repite=False,
        discapacidad=discapacidad,
        orfandad=orfandad,
        familia_numerosa=familia_numerosa,
        reside_fuera=reside_fuera,
    ))
    idx += 1

# Mezclar para que los descartados no estén agrupados al principio
random.shuffle(records)
for i, r in enumerate(records):
    r["id_solicitud"] = f"SOL-MEC-{i + 1:03d}"

# --- Escribir solicitudes_beca_mec.csv ---
fieldnames = [
    "id_solicitud", "nif_solicitante", "nombre_solicitante",
    "domicilio_familiar", "municipio_domicilio", "provincia_domicilio",
    "reside_fuera_domicilio", "ciudad_residencia_curso",
    "renta_anual_familiar", "num_miembros_unidad_familiar",
    "discapacidad", "orfandad", "familia_numerosa",
    "nacionalidad_espanola", "repite_curso",
]

solicitudes_path = os.path.join(OUTPUT_DIR, "solicitudes_beca_mec.csv")
with open(solicitudes_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(records)

print(f"[OK] {solicitudes_path}  →  {len(records)} registros")

# --- Escribir umbrales_renta_mec.csv ---
umbrales_path = os.path.join(OUTPUT_DIR, "umbrales_renta_mec.csv")
with open(umbrales_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["num_miembros", "umbral_1_euros", "umbral_2_euros"])
    writer.writeheader()
    for nm, (u1, u2) in UMBRALES.items():
        writer.writerow({"num_miembros": nm, "umbral_1_euros": u1, "umbral_2_euros": u2})

print(f"[OK] {umbrales_path}  →  {len(UMBRALES)} filas")

# --- Resumen de distribución ---
descartados_nac  = sum(1 for r in records if not r["nacionalidad_espanola"])
descartados_rep  = sum(1 for r in records if r["repite_curso"])
descartados_rent = sum(
    1 for r in records
    if r["nacionalidad_espanola"] and not r["repite_curso"]
    and r["renta_anual_familiar"] > UMBRALES[r["num_miembros_unidad_familiar"]][1]
)
elegibles = len(records) - descartados_nac - descartados_rep - descartados_rent

print(f"\nDistribución:")
print(f"  Descartados (nacionalidad): {descartados_nac}")
print(f"  Descartados (repite curso): {descartados_rep}")
print(f"  Descartados (renta > u2):   {descartados_rent}")
print(f"  Elegibles:                  {elegibles}")
