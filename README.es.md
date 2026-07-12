# Z-Array

[![Versión de Zig](https://img.shields.io/badge/zig-0.16-orange.svg)](https://ziglang.org/)
[![Licencia: MIT](https://img.shields.io/badge/Licencia-MIT-blue.svg)](LICENSE)

**Z-Array** es una implementación de array dinámico de alto rendimiento compatible con ECMAScript, escrito en Zig 0.16. Diseñado para ser un componente central para motores JavaScript como Bun o QuickJS, Z-Array proporciona una API de array completa que refleja las especificaciones de ECMAScript mientras aprovecha las potentes características de tiempo de compilación y garantías de seguridad de Zig.

[🇬🇧 English Version](README.md)

## Características

- ✅ **Cobertura completa de `Array.prototype`** (incluyendo ES2023: `toReversed`, `toSorted`, `toSpliced`, `with`, `entries`/`keys`/`values`, `toString`) para el caso genérico homogéneo de tipado estático — ver [Limitaciones de Diseño](#limitaciones-de-diseño) para lo que queda fuera de alcance de forma consciente.
- ⚡ **Alto Rendimiento**: Construido con Zig para velocidad óptima y eficiencia de memoria
- 🔒 **Seguro en Memoria**: Aprovecha el sistema de asignadores de Zig para gestión controlada de memoria
- 🎯 **Genérico de Tipos**: Funciona con cualquier tipo de datos a través de genéricos en tiempo de compilación
- 🧪 **Probado Exhaustivamente**: Suite de pruebas completa que cubre toda la funcionalidad
- 🎨 **Bloques Etiquetados**: Usa la característica de switch/bloques etiquetados de Zig para flujo de control elegante
- 🔗 **Núcleo numérico compartido con [z-number](https://github.com/carlos-sweb/z-number)**: formateo spec-exacto de `f64`/`f32` (nomenclatura correcta de `NaN`/`Infinity`, umbrales de notación exponencial) para `join`/`toString`/`toLocaleString`, más un puente `indexFromNumber()` para embeber en un motor JS real — reflejando cómo V8 y QuickJS comparten código de conversión de valores entre `Array` y `Number` en vez de mantenerlos completamente independientes.
- 🛡️ **Manejo de Errores**: Manejo elegante de errores con tipos de error personalizados

## Estructura del Proyecto

```
z-array/
├── src/
│   ├── zarray.zig              # Implementación central de ZArray
│   ├── errors.zig              # Tipos de error personalizados
│   ├── (equality.strictEquals/sameValueZero/hash re-exportado de la dependencia z-equality)
│   ├── stringify.zig           # Serialización genérica para join()/toString() (floats spec-exactos vía znumber)
│   ├── jsvalue.zig             # indexFromNumber(): puente JS Number -> índice para embebido
│   └── methods/
│       ├── basic.zig           # Métodos básicos (push, pop, shift, unshift)
│       ├── iteration.zig       # Métodos de iteración (map, filter, forEach, reduce)
│       ├── search.zig          # Métodos de búsqueda (find, indexOf, includes, some, every)
│       ├── manipulation.zig    # Métodos de manipulación (slice, splice, concat, reverse)
│       └── iterators.zig       # entries()/keys()/values()
├── tests/
│   ├── basic_test.zig
│   ├── iteration_test.zig
│   ├── search_test.zig
│   ├── manipulation_test.zig
│   ├── iterators_test.zig
│   ├── static_test.zig
│   ├── equality_test.zig
│   └── jsvalue_test.zig
├── build.zig
├── README.md
└── README.es.md
```

## Instalación

### Dependencias

Z-Array depende de [z-number](https://github.com/carlos-sweb/z-number) (mismo autor) para el formateo numérico spec-exacto y la coerción de índices — ver [Características](#características) — y de [z-equality](https://github.com/carlos-sweb/z-equality) para los algoritmos de Strict Equality/SameValueZero y hash de contenido (`zarray.equality` es un re-export transparente de ese paquete, extraído para que `z-value`/`z-map`/`z-set` compartan la misma implementación en vez de duplicarla). En `build.zig.zon` ambos se resuelven hoy como paths locales hermanos:
```zig
.znumber = .{ .path = "../z-number" },
.zequality = .{ .path = "../z-equality" },
```
Una vez que tengan commits publicados y etiquetados que quieras fijar, cámbialos por dependencias git:
```bash
zig fetch --save git+https://github.com/carlos-sweb/z-number.git
zig fetch --save git+https://github.com/carlos-sweb/z-equality.git
```

### Requisitos Previos

- Zig 0.16 o superior

### Uso en tu Proyecto

1. Clona este repositorio:
```bash
git clone https://github.com/yourusername/z-array.git
```

2. Agrega Z-Array a tu `build.zig.zon` (gestor de paquetes de Zig):
```zig
.dependencies = .{
    .zarray = .{
        .url = "https://github.com/yourusername/z-array/archive/main.tar.gz",
        .hash = "...", // zig proporcionará esto
    },
},
```

3. Importa en tu `build.zig`:
```zig
const zarray = b.dependency("zarray", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zarray", zarray.module("zarray"));
```

4. Usa en tu código:
```zig
const ZArray = @import("zarray").ZArray;
```

## Inicio Rápido

```zig
const std = @import("std");
const ZArray = @import("zarray").ZArray;

pub fn main() !void {
    var gpa:std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Crea un array de enteros
    var arr = ZArray(i32).init(allocator);
    defer arr.deinit();

    // Agrega elementos
    _ = try arr.push(10);
    _ = try arr.push(20);
    _ = try arr.push(30);

    // Operación map
    var doubled = try arr.map(i32, {}, struct {
        fn callback(_: void, item: i32, index: usize) i32 {
            _ = index;
            return item * 2;
        }
    }.callback);
    defer doubled.deinit();

    // Operación filter
    var filtered = try arr.filter({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return item > 15;
        }
    }.predicate);
    defer filtered.deinit();

    std.debug.print("Original: {any}\n", .{arr.toSlice()});
    std.debug.print("Duplicado: {any}\n", .{doubled.toSlice()});
    std.debug.print("Filtrado: {any}\n", .{filtered.toSlice()});
}
```

## Referencia de API

### Métodos Básicos

| Método | Equivalente ECMAScript | Descripción |
|--------|------------------------|-------------|
| `push(value)` | `array.push()` | Agregar elemento al final |
| `pop()` | `array.pop()` | Quitar y retornar último elemento |
| `shift()` | `array.shift()` | Quitar y retornar primer elemento |
| `unshift(value)` | `array.unshift()` | Agregar elemento al principio |
| `fill(value, start, end)` | `array.fill()` | Llenar array con valor; `start`/`end` negativos cuentan desde el final |
| `copyWithin(target, start, end)` | `array.copyWithin()` | Copiar sección del array a otra ubicación |
| `at(index)` | `array.at()` | Obtener elemento por índice; los índices negativos cuentan desde el final |

### Métodos de Iteración

| Método | Equivalente ECMAScript | Descripción |
|--------|------------------------|-------------|
| `forEach(ctx, callback)` | `array.forEach()` | Ejecutar función para cada elemento |
| `map(U, ctx, callback)` | `array.map()` | Crear nuevo array con valores mapeados |
| `filter(ctx, predicate)` | `array.filter()` | Crear nuevo array con elementos filtrados |
| `reduce(U, initial, ctx, callback)` | `array.reduce()` | Reducir a un solo valor |
| `reduceRight(U, initial, ctx, callback)` | `array.reduceRight()` | Reducir de derecha a izquierda |
| `flatMap(U, ctx, callback)` | `array.flatMap()` | Mapear y luego aplanar |

### Métodos de Búsqueda

| Método | Equivalente ECMAScript | Descripción |
|--------|------------------------|-------------|
| `indexOf(value, from)` | `array.indexOf()` | Encontrar primer índice del elemento |
| `lastIndexOf(value, from)` | `array.lastIndexOf()` | Encontrar último índice del elemento |
| `includes(value, from)` | `array.includes()` | Verificar si contiene elemento |
| `find(ctx, predicate)` | `array.find()` | Encontrar primer elemento coincidente |
| `findIndex(ctx, predicate)` | `array.findIndex()` | Encontrar primer índice coincidente |
| `findLast(ctx, predicate)` | `array.findLast()` | Encontrar último elemento coincidente |
| `findLastIndex(ctx, predicate)` | `array.findLastIndex()` | Encontrar último índice coincidente |
| `some(ctx, predicate)` | `array.some()` | Probar si algún elemento pasa |
| `every(ctx, predicate)` | `array.every()` | Probar si todos los elementos pasan |

### Métodos de Manipulación

| Método | Equivalente ECMAScript | Descripción |
|--------|------------------------|-------------|
| `slice(start, end)` | `array.slice()` | Extraer sección |
| `splice(start, count, items)` | `array.splice()` | Quitar/reemplazar elementos |
| `concat(others)` | `array.concat()` | Combinar arrays |
| `reverse()` | `array.reverse()` | Invertir en el lugar |
| `sort(ctx, compareFn)` | `array.sort()` | Ordenar en el lugar |
| `join(separator, alloc)` | `array.join()` | Unir a cadena |
| `toString(alloc)` | `array.toString()` | Equivalente a `join(",")` |
| `toLocaleString(alloc)` | `array.toLocaleString()` | Como `toString()`; usa `T.toLocaleString()` por elemento si está disponible |
| `toReversed()` | `array.toReversed()` | Como `reverse()` pero retorna un nuevo array |
| `toSorted(ctx, compareFn)` | `array.toSorted()` | Como `sort()` pero retorna un nuevo array |
| `toSpliced(start, count, items)` | `array.toSpliced()` | Como `splice()` pero retorna el array resultante completo |
| `with(index, value)` | `array.with()` | Nuevo array con un elemento reemplazado; **lanza error** en índice fuera de rango (a diferencia del resto de la API, que clampa) |
| `flat(comptime depth)` | `array.flat(depth)` | Aplana `ZArray`s anidados por `depth` niveles (depth es obligatorio — Zig no tiene parámetros por defecto) |
| `flatShallow()` | `array.flat()` | Equivalente a `flat(1)` |
| `flatDeep()` | `array.flat(Infinity)` | Aplana todos los niveles de anidamiento presentes en el tipo |

### Métodos de Iteración (protocolo)

| Método | Equivalente ECMAScript | Descripción |
|--------|------------------------|-------------|
| `values()` | `array.values()` | Iterador sobre los valores (`.next() ?T`) |
| `keys()` | `array.keys()` | Iterador sobre los índices |
| `entries()` | `array.entries()` | Iterador sobre pares `{index, value}` |

### Métodos Estáticos

| Método | Equivalente ECMAScript | Descripción |
|--------|------------------------|-------------|
| `ZArray(T).of(alloc, values)` | `Array.of(...)` | Construir un `ZArray(T)` desde un slice |
| `ZArray(T).from(U, alloc, source, ctx, mapFn)` | `Array.from(iterable, mapFn)` | Construir un `ZArray(T)` desde un slice de `U`, mapeando cada elemento |
| `isZArray(comptime X)` | `Array.isArray(x)` | Verificación en tiempo de compilación: ¿es `X` un `ZArray(U)`? Resuelto en comptime porque Zig es de tipado estático |
| `indexFromNumber(value: f64)` | (`ToIntegerOrInfinity` aplicado a argumentos de `slice`/`splice`/`at`/...) | Puente para embebido: coerce un JS Number que llega como `f64` al `isize` que esperan los parámetros de índice de esta API. No hace falta para uso Zig-a-Zig normal. |

### Métodos Utilitarios Adicionales

- `unique()` - Eliminar duplicados (SameValueZero + hash de contenido, así que `ZArray([]const u8)` deduplica por contenido del string, no por identidad de memoria)
- `rotateLeft(n)` / `rotateRight(n)` - Rotar array
- `shuffle(random)` - Mezclar aleatoriamente
- `partition(ctx, predicate)` - Dividir en dos arrays
- `groupBy(K, ctx, keyFn)` - Agrupar por función de clave (mismo hash de contenido que `unique()` para el tipo de clave `K`; una clave struct con `eql()` propio debe proveer también un `hash()` que coincida)
- `binarySearch(value, ctx, compareFn)` - Búsqueda binaria para arrays ordenados

## Ejemplos

### Trabajando con Diferentes Tipos

```zig
// Array de strings
var strings = ZArray([]const u8).init(allocator);
defer strings.deinit();

_ = try strings.push("hola");
_ = try strings.push("mundo");

// Los métodos de búsqueda también funcionan con strings (comparan por contenido, no por identidad de puntero)
std.debug.print("Índice de 'mundo': {?d}\n", .{strings.indexOf("mundo", null)});
std.debug.print("Incluye 'hola': {}\n", .{strings.includes("hola", null)});

// Array de booleanos
var flags = ZArray(bool).init(allocator);
defer flags.deinit();

_ = try flags.push(true);
_ = try flags.push(false);
```

### Filtrado y Mapeo Avanzado

```zig
const Context = struct {
    multiplier: i32,
};

var arr = ZArray(i32).init(allocator);
defer arr.deinit();

const values = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
_ = try arr.pushMany(&values);

// Particionar pares e impares
const result = try arr.partition({}, struct {
    fn predicate(_: void, item: i32, index: usize) bool {
        _ = index;
        return @mod(item, 2) == 0;
    }
}.predicate);
defer result.truthy.deinit();
defer result.falsy.deinit();

std.debug.print("Pares: {any}\n", .{result.truthy.toSlice()});
std.debug.print("Impares: {any}\n", .{result.falsy.toSlice()});
```

### Usando Reduce

```zig
var arr = ZArray(i32).init(allocator);
defer arr.deinit();

const values = [_]i32{ 1, 2, 3, 4, 5 };
_ = try arr.pushMany(&values);

const product = arr.reduce(i32, 1, {}, struct {
    fn callback(_: void, acc: i32, item: i32, index: usize) i32 {
        _ = index;
        return acc * item;
    }
}.callback);

std.debug.print("Producto: {d}\n", .{product}); // 120
```

## Compilación y Pruebas

### Ejecutar Todas las Pruebas

```bash
zig build test
```

### Ejecutar Archivo de Prueba Específico

```bash
zig test tests/basic_test.zig
```

### Compilar en Modo Release

```bash
zig build -Doptimize=ReleaseFast
```

## Manejo de Errores

Z-Array usa el sistema de manejo de errores de Zig con tipos de error personalizados:

```zig
pub const ZArrayError = error{
    OutOfMemory,        // Sin memoria
    IndexOutOfBounds,   // Índice fuera de límites
    InvalidArgument,    // Argumento inválido
    EmptyArray,         // Array vacío
    NotSupported,       // No soportado
    TypeMismatch,       // Desajuste de tipo
};
```

Ejemplo de manejo de errores:

```zig
const value = arr.at(10) catch |err| switch (err) {
    error.IndexOutOfBounds => {
        std.debug.print("¡Índice fuera de límites!\n", .{});
        return;
    },
    else => return err,
};
```

## Consideraciones de Rendimiento

- **Asignación de Memoria**: Z-Array crece la capacidad según sea necesario. Usa `reserve()` para pre-asignar y mejorar el rendimiento.
- **Eliminar Elementos**: Usa `swapRemove()` para eliminación O(1) cuando el orden no importa.
- **Arrays Ordenados**: Usa `binarySearch()` para búsqueda O(log n) en lugar de búsqueda lineal.
- **Clonar vs Referencia**: Ten en cuenta cuándo necesitas un clon vs una referencia de slice.

## Limitaciones de Diseño

`ZArray(T)` es genérico pero monomórfico — un solo tipo de elemento `T` por instanciación, como cualquier contenedor genérico en un lenguaje de tipado estático. Algunas partes del spec real de `Array` de ECMAScript son fundamentalmente incompatibles con eso y quedan fuera de alcance por diseño, no por descuido:

- **Arrays heterogéneos** (`[1, "a", true]`): requerirían un tipo dinámico tipo `JSValue` con union etiquetada, una estructura de datos completamente distinta.
- **Holes / arrays dispersos** (`[1, , 3]`): `std.ArrayList(T)` siempre es densa. Si necesitas espacios "ausentes", usa `ZArray(?T)` explícitamente.
- **Coerción dinámica de tipos** (`"5" + 3 == "53"`): no aplica en un lenguaje de tipado estático por definición.
- **`toLocaleString()`**: no existe una base de datos de locales real ni en la biblioteca estándar de Zig ni en z-number, así que sin un `toLocaleString` propio en `T` es solo un alias de `toString()` — el *número en sí* es spec-exacto, pero no hay agrupación de dígitos ni separadores sensibles a locale.
- **`Array.isArray()`**: se resuelve en comptime vía `isZArray(comptime X: type) bool` en vez de en runtime, ya que el tipo siempre se conoce estáticamente.

### Formateo numérico

`join()`/`toString()`/`toLocaleString()` en `ZArray(f32)`/`ZArray(f64)` delegan en `FormattingMethods.toString` de [z-number](https://github.com/carlos-sweb/z-number), igualando a `Number.prototype.toString()` con precisión — arreglando específicamente lo que `std.fmt` de Zig (`"{d}"`) hace mal para efectos de JS: la nomenclatura de `NaN`/`Infinity`/`-Infinity` (Zig imprime `nan`/`inf`/`-inf`), y los umbrales de notación exponencial que JS exige para `|x| >= 1e21` y `|x| < 1e-6` (Zig siempre imprime dígitos posicionales completos). Esto refleja cómo tanto V8 (`Float64ToString`/`NumberToString` en `array-join.tq`) como QuickJS (`js_dtoa` vía `JS_ToStringFree` en `js_array_join`) enrutan la conversión de array a string por el mismo código de formateo numérico que usa `Number.prototype`.

### Semántica de comparación

Los métodos de búsqueda siguen ECMA262 con precisión, lo que significa que `indexOf`/`lastIndexOf`/`count` e `includes` **no** son intercambiables para floats: `indexOf`/`lastIndexOf`/`count` usan Strict Equality Comparison (`NaN !== NaN`), mientras que `includes` usa SameValueZero (`NaN` es igual a `NaN`, `+0` es igual a `-0`). Para structs propios, provee `pub fn eql(a: T, b: T) bool` para controlar la igualdad; si no, cae a `std.meta.eql` campo por campo (nota: los campos slice anidados dentro de un struct sin su propio `.eql` se comparan por identidad de puntero, no por contenido).

### Nota de breaking change

`at()` y `fill()` cambiaron el tipo de sus parámetros de índice de `usize` a `isize` para soportar índices negativos (`at(-1)` para el último elemento, `fill(v, -2, null)` para los últimos dos), igualando a `Array.prototype.at()`/`fill()` y a la convención de índices negativos que ya usan `slice()`/`splice()`/`copyWithin()`/`with()`.

## Contribuir

¡Las contribuciones son bienvenidas! Por favor, siéntete libre de enviar un Pull Request. Para cambios importantes, abre primero un issue para discutir qué te gustaría cambiar.

1. Haz fork del repositorio
2. Crea tu rama de característica (`git checkout -b feature/caracteristica-increible`)
3. Haz commit de tus cambios (`git commit -m 'Agregar característica increíble'`)
4. Sube a la rama (`git push origin feature/caracteristica-increible`)
5. Abre un Pull Request

## Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo LICENSE para detalles.

## Agradecimientos

- Inspirado por la especificación de Array de ECMAScript
- Construido con la excelente biblioteca estándar de Zig
- Diseñado para integración con motores JavaScript como Bun y QuickJS

## Hoja de Ruta

- [ ] Soporte para funcionalidad tipo TypedArray
- [ ] Métodos de iteración asíncrona
- [ ] Optimizaciones SIMD para operaciones numéricas
- [ ] ABI C para integración FFI más fácil
- [ ] Benchmarks de rendimiento

---

Hecho con ❤️ usando Zig
