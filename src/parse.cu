/*
    Copyright 2017 Zheyong Fan, Ville Vierimaa, Mikko Ervasti, and Ari Harju
    This file is part of GPUMD.
    GPUMD is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    GPUMD is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with GPUMD.  If not, see <http://www.gnu.org/licenses/>.
*/




#include "common.h"
#include "parse.h"




/*----------------------------------------------------------------------------80
	Check if the string is a valid integer
------------------------------------------------------------------------------*/

static int is_valid_int (const char *s, int *result)
{
	if (s == NULL || *s == '\0')
		return 0;

	char *p;
	errno = 0;
	*result = (int) strtol (s, &p, 0);

	if (errno != 0 || s == p || *p != 0)
		return 0;
	else
		return 1;
}




/*----------------------------------------------------------------------------80
	Check if the string is a valid floating point number
------------------------------------------------------------------------------*/

static int is_valid_real (const char *s, real *result)
{
	if (s == NULL || *s == '\0')
		return 0;

	char *p;
	errno = 0;
	*result = strtod (s, &p);

    if (errno != 0 || s == p || *p != 0)
        return 0;
    else
        return 1;
}




static void parse_potential(char **param, int num_param, Files *files)
{
    if (num_param != 2)
    {
        print_error("potential should have 1 parameter.\n");
    }
    strcpy(files->potential_in, param[1]);
}




static void parse_velocity(char **param, int num_param, Parameters *para)
{
    if (num_param != 2)
    {
        print_error("velocity should have 1 parameter.\n");
    }
    if (!is_valid_real(param[1], &para->initial_temperature))
    {
        print_error("initial temperature should be a real number.\n");
    }
    if (para->initial_temperature <= 0.0)
    {
        print_error("initial temperature should be a positive number.\n");
    }
    printf("INPUT: initial temperature is %g K.\n", para->initial_temperature);
}




static void parse_ensemble (char **param,  int num_param, Parameters *para)
{
    // 1. Determine the integration method
    if (strcmp(param[1], "nve") == 0)
    {
        para->ensemble = 0;
        if (num_param != 2)
        {
            print_error("ensemble nve should have 0 parameter.\n");
        }
    }
    else if (strcmp(param[1], "nvt_ber") == 0)
    {
        para->ensemble = 1;
        if (num_param != 5)
        {
            print_error("ensemble nvt_ber should have 3 parameters.\n");
        }
    }
    else if (strcmp(param[1], "npt_ber") == 0)
    {
        para->ensemble = 2;
        if (num_param != 9)
        {
            print_error("ensemble npt_ber should have 7 parameters.\n"); 
        } 
    }
    else if (strcmp(param[1], "nvt_nhc") == 0)
    {
        para->ensemble = 3;
        if (num_param != 5)
        {
            print_error("ensemble nvt_nhc should have 3 parameters.\n"); 
        }
    }
    else if (strcmp(param[1], "heat_nhc") == 0)
    {
        para->ensemble = 4;
        if (num_param != 7)
        {
            print_error("ensemble heat_nhc should have 5 parameters.\n"); 
        }
    }
    else
    {
        print_error("invalid ensemble type.\n");
    }

    // 2. Temperatures and temperature_coupling
    if (para->ensemble >= 1 && para->ensemble <= 3) // may change temperature
    {	
        // initial temperature
        if (!is_valid_real(param[2], &para->temperature1))
        {
            print_error("ensemble temperature should be a real number.\n");
        }
        if (para->temperature1 <= 0.0)
        {
            print_error("ensemble temperature should be a positive number.\n");
        }

        // final temperature
        if (!is_valid_real(param[3], &para->temperature2))
        {
            print_error("ensemble temperature should be a real number.\n");
        }
        if (para->temperature2 <= 0.0)
        {
            print_error("ensemble temperature should be a positive number.\n");
        }

        para->temperature = para->temperature1;

        // temperature_coupling
        if (!is_valid_real(param[4], &para->temperature_coupling))
        {
            print_error("temperature_coupling should be a real number.\n");
        }
        if (para->temperature_coupling <= 0.0)
        {
            print_error("temperature_coupling should be a positive number.\n");
        }
    }

    if (para->ensemble == 4) // heating and cooling wiht fixed temperatures
    {	
        // temperature
        if (!is_valid_real(param[2], &para->temperature))
        {
            print_error("ensemble temperature should be a real number.\n");
        }
        if (para->temperature <= 0.0)
        {
            print_error("ensemble temperature should be a positive number.\n");
        }

        // temperature_coupling
        if (!is_valid_real(param[3], &para->temperature_coupling))
        {
            print_error("temperature_coupling should be a real number.\n");
        }
        if (para->temperature_coupling <= 0.0)
        {
            print_error("temperature_coupling should be a positive number.\n");
        }
    }

    // 3. Pressures and pressure_coupling
    real pressure[3];
    if (para->ensemble == 2)
    {  
        // pressures:   
        for (int i = 0; i < 3; i++)
        {
            if (!is_valid_real(param[5+i], &pressure[i]))
            {
                print_error("ensemble pressure should be a real number.\n");
            }
        }  
        // Change the unit of pressure form GPa to that used in the code
        para->pressure_x = pressure[0] / PRESSURE_UNIT_CONVERSION;
        para->pressure_y = pressure[1] / PRESSURE_UNIT_CONVERSION;
        para->pressure_z = pressure[2] / PRESSURE_UNIT_CONVERSION;

        // pressure_coupling:
        if (!is_valid_real(param[8], &para->pressure_coupling))
        {
            print_error("pressure_coupling should be a real number.\n");
        } 
        if (para->pressure_coupling <= 0.0)
        {
            print_error("pressure_coupling should be a positive number.\n");
        }
    }

    // 4. For heating and cooling with the Nose-Hoover chain method
    if (para->ensemble == 4) 
    {  
        para->heat.compute = 1;
        if (!is_valid_real(param[4], &para->heat.delta_temperature))
        {
            print_error("delta_temperature should be a real number.\n");
        } 
        if (!is_valid_int(param[5], &para->heat.source))
        {
            print_error("heat.source should be an integer.\n");
        }
        if (!is_valid_int(param[6], &para->heat.sink))
        {
            print_error("heat.sink should be an integer.\n");
        }
    }

    switch (para->ensemble)
    {
        case 0:
            printf("INPUT: Use NVE ensemble for this run.\n");
            break;
        case 1:
            printf("INPUT: Use NVT ensemble for this run.\n");
            printf("       choose the Berendsen method.\n"); 
            printf("       initial temperature is %g K.\n", para->temperature1);
            printf("       final temperature is %g K.\n", para->temperature2);
            printf("       T_coupling is %g.\n", para->temperature_coupling);
            break;
        case 2:
            printf("INPUT: Use NPT ensemble for this run.\n");
            printf("       choose the Berendsen method.\n");      
            printf("       initial temperature is %g K.\n", para->temperature1);
            printf("       final temperature is %g K.\n", para->temperature2);
            printf("       T_coupling is %g.\n", para->temperature_coupling);
            printf("       pressure_x is %g GPa.\n", pressure[0]);
            printf("       pressure_y is %g GPa.\n", pressure[1]);
            printf("       pressure_z is %g GPa.\n", pressure[2]);
            printf("       p_coupling is %g.\n", para->pressure_coupling);
            break;
        case 3:
            printf("INPUT: Use NVT ensemble for this run.\n");
            printf("       choose the Nose-Hoover chain method.\n"); 
            printf("       initial temperature is %g K.\n", para->temperature1);
            printf("       final temperature is %g K.\n", para->temperature2);
            printf("       T_coupling is %g.\n", para->temperature_coupling);
            break;  
        case 4:
            printf("INPUT: Integrate with heating and cooling for this run.\n");
            printf("       choose the Nose-Hoover chain method.\n"); 
            printf("       temperature is %g K.\n", para->temperature);
            printf("       T_coupling is %g.\n", para->temperature_coupling);
            printf("       delta_T is %g K.\n", para->heat.delta_temperature);
            printf("       heat source is group %d.\n", para->heat.source);
            printf("       heat sink is group %d.\n", para->heat.sink);
            break; 
        default:
            print_error("invalid ensemble type.\n");
            break; 
    }
}




static void parse_time_step (char **param,  int num_param, Parameters *para)
{
    if (num_param != 2)
    {
        print_error("time_step should have 1 parameter.\n");
    }
    if (!is_valid_real(param[1], &para->time_step))
    {
        print_error("time_step should be a real number.\n");
    } 
    printf("INPUT: time_step for this run is %g fs.\n", para->time_step);
    para->time_step /= TIME_UNIT_CONVERSION;
}




static void parse_neighbor
(
    char **param,  int num_param, 
    Parameters *para, Force_Model *force_model
)
{
    para->neighbor.update = 1;

    if (num_param != 2)
    {
        print_error("neighbor should have 1 parameter.\n");
    }
    if (!is_valid_real(param[1], &para->neighbor.skin))
    {
        print_error("neighbor list skin should be a number.\n");
    } 
    printf
    ("INPUT: build neighbor list with a skin of %g A.\n", para->neighbor.skin);

    // change the cutoff
    para->neighbor.rc = force_model->rc + para->neighbor.skin;
}




static void parse_dump_thermo(char **param,  int num_param, Parameters *para)
{
    if (num_param != 2)
    {
        print_error("dump_thermo should have 1 parameter.\n");
    }
    if (!is_valid_int(param[1], &para->sample_interval_thermo))
    {
        print_error("thermo dump interval should be an integer number.\n");
    } 
    para->dump_thermo = 1;
    printf
    ("INPUT: dump thermo every %d steps.\n", para->sample_interval_thermo);
}




static void parse_dump_position(char **param,  int num_param, Parameters *para)
{
    if (num_param != 2)
    {
        print_error("dump_position should have 1 parameter.\n");
    }
    if (!is_valid_int(param[1], &para->sample_interval_position))
    {
        print_error("position dump interval should be an integer number.\n");
    } 
    para->dump_position = 1;
    printf
    ("INPUT: dump position every %d steps.\n", para->sample_interval_position);
}




static void parse_dump_velocity(char **param,  int num_param, Parameters *para)
{
    if (num_param != 2)
    {
        print_error("dump_velocity should have 1 parameter.\n");
    }
    if (!is_valid_int(param[1], &para->sample_interval_velocity))
    {
        print_error("velocity dump interval should be an integer number.\n");
    } 
    para->dump_velocity = 1;
    printf
    ("INPUT: dump velocity every %d steps.\n", para->sample_interval_velocity);
}




static void parse_dump_force(char **param,  int num_param,Parameters *para)
{
    if (num_param != 2)
    {
        print_error("dump_force should have 1 parameter.\n");
    }
    if (!is_valid_int(param[1], &para->sample_interval_force))
    {
        print_error("force dump interval should be an integer number.\n");
    } 
    para->dump_force = 1;
    printf("INPUT: dump force every %d steps.\n", para->sample_interval_force);
}




static void parse_dump_potential(char **param,  int num_param,Parameters *para)
{
    if (num_param != 2)
    {
        print_error("dump_potential should have 1 parameter.\n");
    }
    if (!is_valid_int(param[1], &para->sample_interval_potential))
    {
        print_error("potential dump interval should be an integer number.\n");
    } 
    para->dump_potential = 1;
    printf
    (
        "INPUT: dump potential every %d steps.\n", 
        para->sample_interval_potential
    );
}




static void parse_dump_virial(char **param,  int num_param,Parameters *para)
{
    if (num_param != 2)
    {
        print_error("dump_virial should have 1 parameter.\n");
    }
    if (!is_valid_int(param[1], &para->sample_interval_virial))
    {
        print_error("virial dump interval should be an integer number.\n");
    } 
    para->dump_force = 1;
    printf
    ("INPUT: dump virial every %d steps.\n", para->sample_interval_virial);
}




static void parse_compute_vac(char **param,  int num_param, Parameters *para)
{
    printf("INPUT: compute VAC.\n");
    para->vac.compute = 1;

    if (num_param != 4)
    {
        print_error("compute_vac should have 3 parameters.\n");
    }

    // sample interval
    if (!is_valid_int(param[1], &para->vac.sample_interval))
    {
        print_error("sample interval for VAC should be an integer number.\n");
    }
    if (para->vac.sample_interval <= 0)
    {
        print_error("sample interval for VAC should be positive.\n");
    }
    printf("       sample interval is %d.\n", para->vac.sample_interval);

    // number of correlation steps
    if (!is_valid_int(param[2], &para->vac.Nc))
    {
        print_error("Nc for VAC should be an integer number.\n");
    }
    if (para->vac.Nc <= 0)
    {
        print_error("Nc for VAC should be positive.\n");
    }
    printf("       Nc is %d.\n", para->vac.Nc);

    // maximal omega
    if (!is_valid_real(param[3], &para->vac.omega_max))
    {
        print_error("omega_max should be a real number.\n");
    }
    if (para->vac.omega_max <= 0)
    {
        print_error("omega_max should be positive.\n");
    }
    printf("       omega_max is %g THz.\n", para->vac.omega_max);
}




static void parse_compute_hac(char **param,  int num_param,Parameters *para)
{
    para->hac.compute = 1;

    printf("INPUT: compute HAC.\n");

    if (num_param != 4)
    {
        print_error("compute_hac should have 3 parameters.\n");
    }

    if (!is_valid_int(param[1], &para->hac.sample_interval))
    {
        print_error("sample interval for HAC should be an integer number.\n");
    }
    printf("       sample interval is %d.\n", para->hac.sample_interval);

    if (!is_valid_int(param[2], &para->hac.Nc))
    {
        print_error("Nc for HAC should be an integer number.\n");
    }
    printf("       Nc is %d\n", para->hac.Nc);

    if (!is_valid_int(param[3], &para->hac.output_interval))
    {
        print_error("output_interval for HAC should be an integer number.\n");
    }
    printf("       output_interval is %d\n", para->hac.output_interval);
}




static void parse_compute_shc(char **param,  int num_param, Parameters *para)
{
    printf("INPUT: compute SHC.\n");
    para->shc.compute = 1;

    if (num_param != 6)
    {
        print_error("compute_shc should have 5 parameters.\n");
    }

    // sample interval 
    if (!is_valid_int(param[1], &para->shc.sample_interval))
    {
        print_error("shc.sample_interval should be an integer.\n");
    }  
    printf
    ("       sample interval for SHC is %d.\n", para->shc.sample_interval);

    // number of correlation data
    if (!is_valid_int(param[2], &para->shc.Nc))
    {
        print_error("Nc for SHC should be an integer.\n");
    }  
    printf("       number of correlation data is %d.\n", para->shc.Nc);

    // number of time origins 
    if (!is_valid_int(param[3], &para->shc.M))
    {
        print_error("M for SHC should be an integer.\n");
    }  
    printf("       number of time origions is %d.\n", para->shc.M);

    // block A 
    if (!is_valid_int(param[4], &para->shc.block_A))
    {
        print_error("block_A for SHC should be an integer.\n");
    }  
    printf
    ("       record the heat flowing from group %d.\n", para->shc.block_A);
    
    // block B 
    if (!is_valid_int(param[5], &para->shc.block_B))
    {
        print_error("block_B for SHC should be an integer.\n");
    }  
    printf
    ("       record the heat flowing into group %d.\n", para->shc.block_B);
}




static void parse_deform(char **param,  int num_param, Parameters *para)
{
    printf("INPUT: compute the stress-strain relation.\n");

    para->strain.compute = 1;

    if (num_param != 2)
    {
        print_error("deform should have 1 parameters.\n");
    }

    // engineering strain rate
    if (!is_valid_real(param[1], &para->strain.rate))
    {
        print_error("strain.rate should be a real number.\n");
    }   
    printf
    (
        "       engineering strain rate is %g A/step.\n", 
        para->strain.rate
    );

}




static void parse_compute_temp(char **param,  int num_param, Parameters *para)
{
    para->heat.sample = 1;
    if (num_param != 2)
    {
        print_error("compute_temp should have 1 parameter.\n");
    }
    if (!is_valid_int(param[1], &para->heat.sample_interval))
    {
        print_error("temperature sampling interval should be an integer.\n");
    }  
    printf
    (
        "INPUT: sample block temperatures every %d steps.\n", 
        para->heat.sample_interval
    );
}




static void parse_fix(char **param, int num_param, Parameters *para)
{
    if (num_param != 2)
    {
        print_error("fix should have 1 parameter.\n");
    }
    if (!is_valid_int(param[1], &para->fixed_group))
    {
        print_error("fixed_group should be an integer.\n");
    }  
    printf("INPUT: group %d will be fixed.\n", para->fixed_group);
}




static void parse_run(char **param,  int num_param, Parameters *para)
{
    if (num_param != 2)
    {
        print_error("run should have 1 parameter.\n");
    }
    if (!is_valid_int(param[1], &para->number_of_steps))
    {
        print_error("number of steps should be an integer.\n");
    }
    printf("INPUT: run %d steps.\n", para->number_of_steps);
}




void parse
(
    char **param, int num_param, Files *files, Parameters *para,
    Force_Model *force_model, int *is_potential,int *is_velocity,int *is_run
)
{
    if (strcmp(param[0], "potential") == 0)
    {
        *is_potential = 1;
        parse_potential(param, num_param, files);
    }
    else if (strcmp(param[0], "velocity") == 0)
    {
        *is_velocity = 1;
        parse_velocity(param, num_param, para);
    }
    else if (strcmp(param[0], "ensemble")       == 0) 
    {
        parse_ensemble(param, num_param, para);
    }
    else if (strcmp(param[0], "time_step")      == 0) 
    {
        parse_time_step(param, num_param, para);
    }
    else if (strcmp(param[0], "neighbor")       == 0) 
    {
        parse_neighbor(param, num_param, para, force_model);
    }
    else if (strcmp(param[0], "dump_thermo")    == 0) 
    {
        parse_dump_thermo(param, num_param, para);
    }
    else if (strcmp(param[0], "dump_position")  == 0) 
    {
        parse_dump_position(param, num_param, para);
    }
    else if (strcmp(param[0], "dump_velocity")  == 0) 
    {
        parse_dump_velocity(param, num_param, para);
    }
    else if (strcmp(param[0], "dump_force")     == 0) 
    {
        parse_dump_force(param, num_param, para);
    }
    else if (strcmp(param[0], "dump_potential") == 0) 
    {
        parse_dump_potential(param, num_param, para);
    }
    else if (strcmp(param[0], "dump_virial")    == 0) 
    {
        parse_dump_virial(param, num_param, para);
    }
    else if (strcmp(param[0], "compute_vac")    == 0) 
    {
        parse_compute_vac(param, num_param, para);
    }
    else if (strcmp(param[0], "compute_hac")    == 0) 
    {
        parse_compute_hac(param, num_param, para);
    }
    else if (strcmp(param[0], "compute_shc")    == 0) 
    {
        parse_compute_shc(param, num_param, para);
    }
    else if (strcmp(param[0], "deform")         == 0) 
    {
        parse_deform(param, num_param, para);
    }
    else if (strcmp(param[0], "compute_temp")   == 0) 
    {
        parse_compute_temp(param, num_param, para);
    }
    else if (strcmp(param[0], "fix")            == 0) 
    {
        parse_fix(param, num_param, para);
    }
    else if (strcmp(param[0], "run")            == 0)
    {
        *is_run = 1;
        parse_run(param, num_param, para);
    }
    else
    {
        print_error("invalid keyword.\n");
    }
}

