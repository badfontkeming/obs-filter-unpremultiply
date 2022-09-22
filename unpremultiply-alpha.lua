obs = obslua

-- Returns the description displayed in the Scripts window
function script_description()
  return [[Unpremultiply Alpha
  Reverses premultiplication, which is when the colors of a semi-transparent source pixel are being blended with black. Fixes color fringing and bad fadeins/fadeouts with semi-transparent sources.]]
end

-- Called on script startup
function script_load(settings)
  obs.obs_register_source(source_info)
end

-- Definition of the global variable containing the source_info structure
source_info = {}
source_info.id = 'filter-unpremultiply-alpha'              -- Unique string identifier of the source type
source_info.type = obs.OBS_SOURCE_TYPE_FILTER   -- INPUT or FILTER or TRANSITION
source_info.output_flags = obs.OBS_SOURCE_VIDEO -- Combination of VIDEO/AUDIO/ASYNC/etc

-- Returns the name displayed in the list of filters
source_info.get_name = function()
  return "Unpremultiply Alpha"
end

-- Creates the implementation data for the source
source_info.create = function(settings, source)

  -- Initializes the custom data table
  local data = {}
  data.source = source -- Keeps a reference to this filter as a source object
  data.width = 1       -- Dummy value during initialization phase
  data.height = 1      -- Dummy value during initialization phase

  -- Compiles the effect
  obs.obs_enter_graphics()
  local effect_file_path = script_path() .. 'filter-unpremultiply-alpha.effect.hlsl'
  data.effect = obs.gs_effect_create_from_file(effect_file_path, nil)
  obs.obs_leave_graphics()

  -- Calls the destroy function if the effect was not compiled properly
  if data.effect == nil then
    obs.blog(obs.LOG_ERROR, "Effect compilation failed for " .. effect_file_path)
    source_info.destroy(data)
    return nil
  end
  
    -- Retrieves the shader uniform variables
  data.params = {}
  data.params.width = obs.gs_effect_get_param_by_name(data.effect, "width")
  data.params.height = obs.gs_effect_get_param_by_name(data.effect, "height")
  data.params.dividepow = obs.gs_effect_get_param_by_name(data.effect, "dividepow")

  -- Calls update to initialize the rest of the properties-managed settings
  source_info.update(data, settings)

  return data
end

-- Destroys and release resources linked to the custom data
source_info.destroy = function(data)
  if data.effect ~= nil then
    obs.obs_enter_graphics()
    obs.gs_effect_destroy(data.effect)
    data.effect = nil
    obs.obs_leave_graphics()
  end
end

-- Returns the width of the source
source_info.get_width = function(data)
  return data.width
end

-- Returns the height of the source
source_info.get_height = function(data)
  return data.height
end

-- Called when rendering the source with the graphics subsystem
source_info.video_render = function(data)
  local parent = obs.obs_filter_get_parent(data.source)
  data.width = obs.obs_source_get_base_width(parent)
  data.height = obs.obs_source_get_base_height(parent)

  obs.obs_source_process_filter_begin(data.source, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)
  obs.gs_blend_state_push();
  obs.gs_blend_function(obs.GS_BLEND_ONE, obs.GS_BLEND_INVSRCALPHA);
  -- Effect parameters initialization goes here
  obs.gs_effect_set_int(data.params.width, data.width)
  obs.gs_effect_set_int(data.params.height, data.height)
  obs.gs_effect_set_float(data.params.dividepow, data.dividepow)

  obs.obs_source_process_filter_end(data.source, data.effect, data.width, data.height)
  obs.gs_blend_state_pop();
end

-- Sets the default settings for this source
source_info.get_defaults = function(settings)
  obs.obs_data_set_default_double(settings, "dividepow", 2.0)
end

-- Gets the property information of this source
source_info.get_properties = function(data)
  local props = obs.obs_properties_create()
  obs.obs_properties_add_text(props, "cloneheroinstructions", "As of PTB v1.0.0.3805-master, Clone Hero should work best with a value of 2. Some artifacting will still be present due to lost color data.", obslua.OBS_TEXT_INFO)
  obs.obs_properties_add_float_slider(props, "dividepow", "Alpha divide exponent", 1, 2, 0.01)

  return props
end

-- Updates the internal data for this source upon settings change
source_info.update = function(data, settings)
  data.dividepow = obs.obs_data_get_double(settings, "dividepow")
end