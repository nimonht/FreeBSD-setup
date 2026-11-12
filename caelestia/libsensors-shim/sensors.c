/*
 * lm-sensors API shim for FreeBSD - see sensors/sensors.h.
 *
 * Exposes one chip ("coretemp") with:
 *   feature 0            "Package id 0"  = hottest core (FreeBSD has no
 *                                          package sensor sysctl)
 *   feature 1..ncpu      "Core N"        = dev.cpu.N.temperature
 * Temperatures need coretemp(4) (Intel) or amdtemp(4) (AMD) to be loaded.
 */
#include <sys/types.h>
#include <sys/sysctl.h>

#include <stdlib.h>
#include <string.h>

#include "sensors/sensors.h"

#define MAX_CPUS 256

static sensors_chip_name chip = { "coretemp", { SENSORS_BUS_TYPE_ISA, 0 }, 0, "/dev/null" };
static sensors_feature features[MAX_CPUS + 1];
static sensors_subfeature subfeatures[MAX_CPUS + 1];
static char names[MAX_CPUS + 1][16];
static int nfeatures;

/* dev.cpu.N.temperature is an int in deci-Kelvin. */
static int
core_temp(int cpu, double *out)
{
	char mib[64];
	int raw;
	size_t len = sizeof(raw);

	snprintf(mib, sizeof(mib), "dev.cpu.%d.temperature", cpu);
	if (sysctlbyname(mib, &raw, &len, NULL, 0) != 0)
		return (-1);
	*out = (raw - 2731) / 10.0;
	return (0);
}

int
sensors_init(FILE *input)
{
	int ncpu = 0, i;
	size_t len = sizeof(ncpu);
	double t;

	(void)input;
	nfeatures = 0;
	if (sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0) != 0 || ncpu < 1)
		return (0);
	if (ncpu > MAX_CPUS)
		ncpu = MAX_CPUS;
	if (core_temp(0, &t) != 0)
		return (0);	/* no thermal driver loaded: zero chips, not an error */

	for (i = 0; i <= ncpu; i++) {
		snprintf(names[i], sizeof(names[i]), "temp%d", i + 1);
		features[i].name = names[i];
		features[i].number = i;
		features[i].type = SENSORS_FEATURE_TEMP;
		features[i].first_subfeature = i;
		subfeatures[i].name = names[i];
		subfeatures[i].number = i;
		subfeatures[i].type = SENSORS_SUBFEATURE_TEMP_INPUT;
		subfeatures[i].mapping = i;
		subfeatures[i].flags = 1;
	}
	nfeatures = ncpu + 1;
	return (0);
}

void
sensors_cleanup(void)
{
	nfeatures = 0;
}

const sensors_chip_name *
sensors_get_detected_chips(const sensors_chip_name *match, int *nr)
{
	(void)match;
	if (nfeatures == 0 || *nr != 0)
		return (NULL);
	(*nr)++;
	return (&chip);
}

const sensors_feature *
sensors_get_features(const sensors_chip_name *name, int *nr)
{
	(void)name;
	if (*nr < 0 || *nr >= nfeatures)
		return (NULL);
	return (&features[(*nr)++]);
}

const sensors_subfeature *
sensors_get_subfeature(const sensors_chip_name *name, const sensors_feature *feature,
    sensors_subfeature_type type)
{
	(void)name;
	if (feature == NULL || type != SENSORS_SUBFEATURE_TEMP_INPUT)
		return (NULL);
	return (&subfeatures[feature->number]);
}

int
sensors_get_value(const sensors_chip_name *name, int subfeat_nr, double *value)
{
	double t, max = -1000.0;
	int i, found = 0;

	(void)name;
	if (subfeat_nr < 0 || subfeat_nr >= nfeatures)
		return (-1);
	if (subfeat_nr > 0)
		return (core_temp(subfeat_nr - 1, value));

	/* "Package": the hottest core. */
	for (i = 0; i < nfeatures - 1; i++) {
		if (core_temp(i, &t) == 0) {
			found = 1;
			if (t > max)
				max = t;
		}
	}
	if (!found)
		return (-1);
	*value = max;
	return (0);
}

/* The caller frees the result, as with the real library. */
char *
sensors_get_label(const sensors_chip_name *name, const sensors_feature *feature)
{
	char buf[32];

	(void)name;
	if (feature == NULL)
		return (NULL);
	if (feature->number == 0)
		snprintf(buf, sizeof(buf), "Package id 0");
	else
		snprintf(buf, sizeof(buf), "Core %d", feature->number - 1);
	return (strdup(buf));
}
