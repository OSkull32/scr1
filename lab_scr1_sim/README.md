# Лабораторная работа 2. SCR1: обработка исключения Illegal instruction

## 1. Цель

Ознакомиться с возможностями настройки архитектуры системы команд, обработкой
исключений/прерываний и принципами работы сборщика программ.

## 2. Вариант задания

**Вариант 1.**

| Параметр | Значение |
|---|---|
| Вид исключения | Illegal instruction |
| Тест | `isa/rv32mi/illegal.S` |
| Reset Vector | `0x400` |
| Trap Vector | `0x200` |
| Обработчик | вывод строки `illegal` |

Рабочий репозиторий: <https://github.com/OSkull32/scr1>, ветка `lab_scr1_sim`
(форк <https://github.com/syntacore/scr1>).

## 3. Порядок выполнения

1. Сделан форк репозитория SCR1 в личный аккаунт и создана ветка
   `lab_scr1_sim`.
2. Получены сабмодули с тестами: `git submodule update --init --recursive`.
3. **Базовый прогон до изменений**: `gmake clean && gmake TARGETS="riscv_isa"` —
   все тесты проходят: `56/56 tests passed`.
4. Список тестов сокращён до одного теста варианта; повторный прогон собирает и
   выполняет ровно один тест: `1/1 tests passed`.
5. В `scr1_arch_description.svh` установлены Reset Vector `0x400` и Trap Vector
   `0x200`.
6. Скорректированы linker-скрипт `link.ld` и макросы сборки `riscv_macros.h`,
   чтобы `_start` и `trap_vector` оказались ровно по новым адресам.
7. В `trap_vector` добавлен вывод строки `illegal` при Illegal instruction.
8. Выполнена симуляция, результаты сохранены в `results/`.
9. Изменения закоммичены в ветку `lab_scr1_sim`.

## 4. Изменённые файлы

| Файл | Что изменено |
|---|---|
| `src/includes/scr1_arch_description.svh` | `SCR1_ARCH_RST_VECTOR` = `0x400`, `SCR1_ARCH_MTVEC_BASE` = `0x200` |
| `sim/tests/riscv_isa/rv32_tests.inc` | из списка оставлен только `isa/rv32mi/illegal.S` |
| `sim/tests/common/link.ld` | `.text.init` размещается с `0x200`; добавлена секция `.text.start` по адресу `0x400` для `_start` |
| `sim/tests/common/riscv_macros.h` | убран `.org 0xC0`; `_start` перенесён в `.section .text.start`; в `trap_vector` добавлен вывод строки `illegal` |

### 4.1. Вектора

`src/includes/scr1_arch_description.svh`:

```systemverilog
parameter bit [`SCR1_XLEN-1:0] SCR1_ARCH_RST_VECTOR = 'h400;  // Reset vector
parameter bit [`SCR1_XLEN-1:0] SCR1_ARCH_MTVEC_BASE = 'h200;  // MTVEC.base
```

### 4.2. Список тестов

`sim/tests/riscv_isa/rv32_tests.inc` (строка `ARCH_lowercase` сохранена — от неё
зависят флаги `-march=rv32imfc...`):

```make
rv32_isa_tests += isa/rv32mi/illegal.S
```

### 4.3. Раскладка образа

`sim/tests/common/link.ld`: `.text.init` начинается с `0x200` - там оказывается
`trap_vector`; `_start` вынесен в отдельную секцию по адресу `0x400`. Служебные
адреса `SIM_EXIT`/`SIM_STOP` (`0xF4`/`0xF8`), по которым тестбенч определяет
завершение теста, не менялись.

```ld
.text.init 0 : {
    ...
    . = 0x200;                 /* было 0x100 */
    PROVIDE(__TEXT_START__ = .);
    *(.text.init)
} >RAM

.text.start 0x400 : {          /* Reset Vector варианта */
    PROVIDE(__TEXT_START_START__ = .);
    *(.text.start)
} >RAM
```

В `sim/tests/common/riscv_macros.h` удалён `.org 0xC0` (иначе `trap_vector`
оказался бы на `0x2C0`), а `_start` перенесён в `.text.start`:

```asm
        .globl _start;
        .section .text.start;
_start:
```

### 4.4. Обработчик исключения

Печать вставлена после проверок `ecall` и до перехода в
`mtvec_handler`: у теста `illegal.S` есть собственный обработчик, и исключение
доходит до него только через эту точку. Проверка `mcause == 2` гарантирует, что
строка печатается именно на Illegal instruction, а не на любом исключении.

```asm
trap_vector:
        csrr a4, mcause
        li   a5, CAUSE_USER_ECALL
        beq  a4, a5, _report
        li   a5, CAUSE_SUPERVISOR_ECALL
        beq  a4, a5, _report
        li   a5, CAUSE_MACHINE_ECALL
        beq  a4, a5, _report
        /* lab2: Illegal instruction -> печать через порт 0xF0000000 */
        csrr a4, mcause
        li   a5, CAUSE_ILLEGAL_INSTRUCTION
        bne  a4, a5, 1f
        lui  a6, 0xf0000           # порт печати тестбенча
        la   a7, msg_trap
msg_loop:
        lb   a5, 0(a7)
        beqz a5, msg_done
        sw   a5, 0(a6)             # тестбенч выводит младший байт
        addi a7, a7, 1
        j    msg_loop
msg_done:
1:      la   a4, mtvec_handler
        ...
        .balign 4
msg_trap:
        .string "illegal"
```

## 5. Результаты

Итог симуляции (`results/test_results.txt`):

```
                     illegal.hex		OK	  PASS
```

Консоль симулятора (`results/sim_results.txt`, ANSI-коды тестбенча убраны):

```
scr1_top_tb_ahb
---Test:                      illegal.hex
illegal                <- строка, выведенная обработчиком
Test passed            <- вердикт тестбенча

#--------------------------------------
# Summary: 1/1 tests passed
#--------------------------------------
```

Адреса в собранном тесте (`nm`/`objdump` по `illegal.elf`):

| Символ | Адрес | Комментарий |
|---|---|---|
| `trap_vector` | `0x200` | Trap Vector варианта |
| `_start` | `0x400` | Reset Vector варианта |
| `msg_trap` | `0x258` | строка `illegal` в `.text.init` |
| `mtvec_handler` | `0x700` | обработчик теста `illegal.S` |
| `SIM_EXIT` | `0xf4` | служебный адрес тестбенча, не менялся |

Раскладка секций (перекрытий нет):

| Секция | Код начинается с | Размер |
|---|---|---|
| `.text.init` | `0x200` (ниже, на `0xF4`, служебные адреса тестбенча) | `0x2A4` |
| `.text.start` | `0x400` | `0x6C` |
| `.text` | `0x500` | `0x440` |

Состав каталога `results/`:

* `test_results.txt` - результат симуляции;
* `illegal.dump` - дизассемблер теста (в нём видно `00000200 <trap_vector>`);
* `sim_results.txt` - лог консоли симулятора;
* `tracelog_core_0.log` - трейс-лог ядра (139 строк, режим `TRACE=1`);
* `simx.vcd` - волновая форма для GTKWave (режим `run_verilator_wf`).

## 6. Что делал

```console
$ git clone -b lab_scr1_sim https://github.com/OSkull32/scr1.git
$ cd scr1
$ git submodule update --init --recursive
$ export PATH=$HOME/riscv-tools/riscv64-unknown-elf/bin:$PATH

# базовый прогон до изменений (все ISA-тесты)
$ gmake clean && gmake TARGETS="riscv_isa"

# после внесения изменений - только тест варианта
$ gmake clean && gmake run_verilator TARGETS="riscv_isa"

# прогон с трейсами
$ gmake clean && gmake run_verilator_wf TARGETS="riscv_isa" TRACE=1
```

Результаты появляются в
`build/verilator_AHB_MAX_imc_IPIC_1_TCM_1_VIRQ_1_TRACE_0/test_results.txt`
(для трассировочного прогона - в каталоге `..._TRACE_1/`).

## 7. Выводы

* Вектора Reset и Trap в SCR1 задаются параметрами ядра
  (`SCR1_ARCH_RST_VECTOR`, `SCR1_ARCH_MTVEC_BASE`) и должны быть согласованы с
  раскладкой программы: положение `_start` и `trap_vector` определяется
  linker-скриптом и макросами `RVTEST_CODE_BEGIN`. Если изменить только
  параметры ядра, тест перестаёт проходить - программа оказывается не по тому
  адресу, откуда стартует процессор.
* Обработчик исключения - это код по адресу из `mtvec`. Для `illegal.S`
  сообщение нужно печатать до перехода в собственный `mtvec_handler` теста,
  иначе исключение обрабатывается раньше и строка не выводится.
* Строка выводится через отладочный порт тестбенча `0xF0000000`: запись по
  этому адресу приводит к печати младшего байта в консоль симулятора.
