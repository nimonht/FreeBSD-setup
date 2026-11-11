/*
 * Minimal lm-sensors compatible API for FreeBSD.
 *
 * lm-sensors is Linux-only. The Caelestia shell plugin uses a small part of
 * its API to read CPU/GPU temperatures. This shim implements exactly that
 * part on top of FreeBSD sysctls (coretemp(4) / amdtemp(4)), so the plugin
 * builds and shows a CPU temperature without touching its source.
 */
#ifndef FREEBSD_SENSORS_SHIM_H
#define FREEBSD_SENSORS_SHIM_H

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SENSORS_API_VERSION 0x500

#define SENSORS_BUS_TYPE_ANY     (-1)
#define SENSORS_BUS_TYPE_I2C     0
#define SENSORS_BUS_TYPE_ISA     1
#define SENSORS_BUS_TYPE_PCI     2
#define SENSORS_BUS_TYPE_SPI     3
#define SENSORS_BUS_TYPE_VIRTUAL 4
#define SENSORS_BUS_TYPE_ACPI    5
#define SENSORS_BUS_TYPE_HID     6
#define SENSORS_BUS_NR_ANY       (-1)

typedef struct sensors_bus_id {
	short type;
	short nr;
} sensors_bus_id;

typedef struct sensors_chip_name {
	char *prefix;
	sensors_bus_id bus;
	int addr;
	char *path;
} sensors_chip_name;

typedef enum sensors_feature_type {
	SENSORS_FEATURE_IN = 0x00,
	SENSORS_FEATURE_FAN = 0x01,
	SENSORS_FEATURE_TEMP = 0x02,
	SENSORS_FEATURE_UNKNOWN = 0x7fffffff
} sensors_feature_type;

typedef enum sensors_subfeature_type {
	SENSORS_SUBFEATURE_TEMP_INPUT = SENSORS_FEATURE_TEMP << 8,
	SENSORS_SUBFEATURE_UNKNOWN = 0x7fffffff
} sensors_subfeature_type;

typedef struct sensors_feature {
	char *name;
	int number;
	sensors_feature_type type;
	int first_subfeature;
	int padding1;
} sensors_feature;

typedef struct sensors_subfeature {
	char *name;
	int number;
	sensors_subfeature_type type;
	int mapping;
	unsigned int flags;
} sensors_subfeature;

int sensors_init(FILE *input);
void sensors_cleanup(void);
const sensors_chip_name *sensors_get_detected_chips(const sensors_chip_name *match, int *nr);
const sensors_feature *sensors_get_features(const sensors_chip_name *name, int *nr);
const sensors_subfeature *sensors_get_subfeature(const sensors_chip_name *name,
    const sensors_feature *feature, sensors_subfeature_type type);
int sensors_get_value(const sensors_chip_name *name, int subfeat_nr, double *value);
char *sensors_get_label(const sensors_chip_name *name, const sensors_feature *feature);

#ifdef __cplusplus
}
#endif

#endif
