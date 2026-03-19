import dynamic from 'next/dynamic';

export interface DynamicMapProps {
  geoJsonData: any;
  userVisits: string[];
}

const DynamicMap = dynamic<DynamicMapProps>(() => import('./Map'), {
  ssr: false,
});

export default DynamicMap;
