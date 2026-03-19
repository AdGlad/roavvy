"use client";

import { MapContainer, GeoJSON } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import "leaflet-defaulticon-compatibility/dist/leaflet-defaulticon-compatibility.css";
import "leaflet-defaulticon-compatibility";
import { DynamicMapProps } from "./DynamicMap";

const VISITED_COLOR = "#2D6A4F";
const UNVISITED_COLOR = "#D1D5DB";
const BORDER_COLOR = "#9CA3AF";

const Map = ({ geoJsonData, userVisits }: DynamicMapProps) => {
  const styleFeature = (feature: any) => {
    const countryCode = feature.properties.ISO_A2;
    const visited = userVisits.includes(countryCode);
    return {
      fillColor: visited ? VISITED_COLOR : UNVISITED_COLOR,
      fillOpacity: 1,
      color: BORDER_COLOR,
      weight: 0.5,
    };
  };

  const onEachFeature = (feature: any, layer: any) => {
    const countryCode = feature.properties.ISO_A2;
    layer.bindPopup(`${feature.properties.NAME} (${countryCode})`);
  };

  return (
    <MapContainer
      center={[20, 0]}
      zoom={2}
      style={{ height: "100%", width: "100%", background: UNVISITED_COLOR }}
      zoomControl={true}
    >
      {geoJsonData && (
        <GeoJSON
          data={geoJsonData}
          style={styleFeature}
          onEachFeature={onEachFeature}
        />
      )}
    </MapContainer>
  );
};

export default Map;
