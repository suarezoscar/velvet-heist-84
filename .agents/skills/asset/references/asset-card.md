# Ficha de asset

| Campo | Valor |
|---|---|
| Nombre (snake_case) | |
| FEAT | |
| Dimensiones objetivo (m) | |
| Pivote | base inferior central |
| Triángulos máximos | |
| Materiales (paleta) | |
| Colisión `-col` | sí / no |

## Lista de comprobación manual (hasta que exista el validador)
- [ ] Dimensiones dentro de ±1 % de la ficha
- [ ] Origen en la base central
- [ ] Escala (1, 1, 1) y rotación (0, 0, 0) aplicadas
- [ ] Solo materiales de la paleta, sin nodos procedurales
- [ ] Bevel aplicado (width 0.02, segments 2)
- [ ] Malla `-col` presente si corresponde
- [ ] Nombres sin espacios ni puntos
- [ ] Triángulos ≤ presupuesto
- [ ] `.glb` exportado por CLI y se importa en Godot sin errores
